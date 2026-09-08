from aws_cdk import (
    CfnOutput,
    Duration,
    Stack,
    aws_certificatemanager as acm,
    aws_dynamodb as dynamodb,
    aws_ec2 as ec2,
    aws_ecr as ecr,
    aws_ecs as ecs,
    aws_elasticloadbalancingv2 as elbv2,
    aws_logs as logs,
    aws_route53 as route53,
    aws_route53_targets as targets,
    aws_secretsmanager as secretsmanager,
)
from constructs import Construct


class ApiStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        table: dynamodb.ITableV2,
        repository: ecr.IRepository,
        anthropic_secret: secretsmanager.ISecret,
        domain: str,
        api_domain: str,
        zone_id: str,
        image_tag: str,
        origin_prefix_list: str,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        zone = route53.HostedZone.from_hosted_zone_attributes(
            self, "Zone", hosted_zone_id=zone_id, zone_name=domain
        )

        self.vpc = ec2.Vpc(
            self,
            "Vpc",
            max_azs=2,
            nat_gateways=0,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="public", subnet_type=ec2.SubnetType.PUBLIC, cidr_mask=24
                )
            ],
            gateway_endpoints={
                "DynamoDB": ec2.GatewayVpcEndpointOptions(
                    service=ec2.GatewayVpcEndpointAwsService.DYNAMODB
                ),
                "S3": ec2.GatewayVpcEndpointOptions(
                    service=ec2.GatewayVpcEndpointAwsService.S3
                ),
            },
        )

        cluster = ecs.Cluster(
            self, "Cluster", vpc=self.vpc, container_insights_v2=ecs.ContainerInsights.ENABLED
        )

        task_definition = ecs.FargateTaskDefinition(
            self, "TaskDef", cpu=256, memory_limit_mib=512
        )

        ip_hash_salt = secretsmanager.Secret(
            self,
            "IpHashSalt",
            secret_name="mss-portfolio/ip-hash-salt",
            generate_secret_string=secretsmanager.SecretStringGenerator(
                exclude_punctuation=True, password_length=32
            ),
        )

        task_definition.add_container(
            "api",
            image=ecs.ContainerImage.from_ecr_repository(repository, image_tag),
            port_mappings=[ecs.PortMapping(container_port=8000)],
            environment={
                "ENV": "production",
                "APP_VERSION": image_tag,
                "DDB_TABLE": table.table_name,
                "AWS_REGION": self.region,
            },
            secrets={
                "ANTHROPIC_API_KEY": ecs.Secret.from_secrets_manager(anthropic_secret),
                "IP_HASH_SALT": ecs.Secret.from_secrets_manager(ip_hash_salt),
            },
            logging=ecs.LogDrivers.aws_logs(
                stream_prefix="api",
                log_retention=logs.RetentionDays.ONE_MONTH,
            ),
            health_check=ecs.HealthCheck(
                command=[
                    "CMD-SHELL",
                    "python -c \"import urllib.request;urllib.request.urlopen('http://localhost:8000/api/v1/health')\"",
                ],
                interval=Duration.seconds(30),
                start_period=Duration.seconds(30),
            ),
        )

        table.grant_read_write_data(task_definition.task_role)

        alb_security_group = ec2.SecurityGroup(
            self,
            "AlbSg",
            vpc=self.vpc,
            description="Accepts only CloudFront origin-facing traffic",
            allow_all_outbound=True,
        )
        alb_security_group.add_ingress_rule(
            ec2.Peer.prefix_list(origin_prefix_list),
            ec2.Port.tcp(443),
            "CloudFront origin-facing ranges",
        )

        self.alb = elbv2.ApplicationLoadBalancer(
            self,
            "Alb",
            vpc=self.vpc,
            internet_facing=True,
            security_group=alb_security_group,
            idle_timeout=Duration.seconds(300),
        )

        certificate = acm.Certificate(
            self,
            "ApiCertificate",
            domain_name=api_domain,
            validation=acm.CertificateValidation.from_dns(zone),
        )

        service = ecs.FargateService(
            self,
            "Service",
            cluster=cluster,
            task_definition=task_definition,
            desired_count=1,
            assign_public_ip=True,
            vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PUBLIC),
            min_healthy_percent=100,
            max_healthy_percent=200,
            circuit_breaker=ecs.DeploymentCircuitBreaker(rollback=True),
        )

        listener = self.alb.add_listener(
            "Https",
            port=443,
            certificates=[certificate],
            ssl_policy=elbv2.SslPolicy.RECOMMENDED_TLS,
            open=False,
        )
        listener.add_targets(
            "ApiTargets",
            port=8000,
            protocol=elbv2.ApplicationProtocol.HTTP,
            targets=[service],
            deregistration_delay=Duration.seconds(15),
            health_check=elbv2.HealthCheck(
                path="/api/v1/health",
                healthy_threshold_count=2,
                interval=Duration.seconds(15),
                timeout=Duration.seconds(5),
            ),
        )

        service.connections.allow_from(
            alb_security_group, ec2.Port.tcp(8000), "ALB to task"
        )

        route53.ARecord(
            self,
            "ApiAlias",
            zone=zone,
            record_name=api_domain,
            target=route53.RecordTarget.from_alias(
                targets.LoadBalancerTarget(self.alb)
            ),
        )

        self.service = service

        CfnOutput(self, "AlbDnsName", value=self.alb.load_balancer_dns_name)
        CfnOutput(self, "ApiDomain", value=api_domain)
        CfnOutput(self, "ServiceName", value=service.service_name)
        CfnOutput(self, "ClusterName", value=cluster.cluster_name)
