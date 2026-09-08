from aws_cdk import (
    CfnOutput,
    RemovalPolicy,
    Stack,
    aws_dynamodb as dynamodb,
    aws_ecr as ecr,
    aws_secretsmanager as secretsmanager,
)
from constructs import Construct


class DataStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.table = dynamodb.TableV2(
            self,
            "Table",
            table_name="mss-portfolio",
            partition_key=dynamodb.Attribute(
                name="pk", type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(name="sk", type=dynamodb.AttributeType.STRING),
            billing=dynamodb.Billing.on_demand(),
            time_to_live_attribute="expires_at",
            point_in_time_recovery_specification=dynamodb.PointInTimeRecoverySpecification(
                point_in_time_recovery_enabled=True
            ),
            removal_policy=RemovalPolicy.RETAIN,
        )

        self.repository = ecr.Repository(
            self,
            "BackendRepo",
            repository_name="mss-portfolio-backend",
            image_scan_on_push=True,
            removal_policy=RemovalPolicy.RETAIN,
            lifecycle_rules=[
                ecr.LifecycleRule(
                    description="Keep the last 10 images",
                    max_image_count=10,
                )
            ],
        )

        self.anthropic_secret = secretsmanager.Secret(
            self,
            "AnthropicApiKey",
            secret_name="mss-portfolio/anthropic-api-key",
            description="Anthropic API key used by the portfolio chat assistant",
            removal_policy=RemovalPolicy.RETAIN,
        )

        CfnOutput(self, "TableName", value=self.table.table_name)
        CfnOutput(self, "RepositoryUri", value=self.repository.repository_uri)
        CfnOutput(self, "AnthropicSecretArn", value=self.anthropic_secret.secret_arn)
