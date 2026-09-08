from aws_cdk import (
    CfnOutput,
    Duration,
    Stack,
    aws_cloudfront as cloudfront,
    aws_ecr as ecr,
    aws_iam as iam,
    aws_s3 as s3,
)
from constructs import Construct

GITHUB_OIDC_URL = "https://token.actions.githubusercontent.com"
CDK_BOOTSTRAP_QUALIFIER = "hnb659fds"


class CicdStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        github_repo: str,
        site_bucket: s3.IBucket,
        distribution: cloudfront.IDistribution,
        repository: ecr.IRepository,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        provider = iam.OpenIdConnectProvider(
            self, "GithubOidc", url=GITHUB_OIDC_URL, client_ids=["sts.amazonaws.com"]
        )

        owner, repo_name = github_repo.split("/")
        sub_pattern = f"repo:{owner}*/{repo_name}*:ref:refs/heads/main"

        self.role = iam.Role(
            self,
            "DeployRole",
            role_name="mss-portfolio-github-deploy",
            description=f"Assumed by GitHub Actions in {github_repo} on main",
            max_session_duration=Duration.hours(1),
            assumed_by=iam.FederatedPrincipal(
                provider.open_id_connect_provider_arn,
                conditions={
                    "StringEquals": {
                        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
                        "token.actions.githubusercontent.com:repository": github_repo,
                        "token.actions.githubusercontent.com:ref": "refs/heads/main",
                    },
                    "StringLike": {
                        "token.actions.githubusercontent.com:sub": sub_pattern,
                    },
                },
                assume_role_action="sts:AssumeRoleWithWebIdentity",
            ),
        )

        self.role.add_to_policy(
            iam.PolicyStatement(
                sid="AssumeCdkBootstrapRoles",
                actions=["sts:AssumeRole"],
                resources=[
                    f"arn:aws:iam::{self.account}:role/cdk-{CDK_BOOTSTRAP_QUALIFIER}-{purpose}-role-{self.account}-{self.region}"
                    for purpose in (
                        "deploy",
                        "file-publishing",
                        "image-publishing",
                        "lookup",
                    )
                ],
            )
        )

        repository.grant_pull_push(self.role)
        self.role.add_to_policy(
            iam.PolicyStatement(
                sid="EcrAuth",
                actions=["ecr:GetAuthorizationToken"],
                resources=["*"],
            )
        )

        site_bucket.grant_read_write(self.role)
        site_bucket.grant_delete(self.role)

        self.role.add_to_policy(
            iam.PolicyStatement(
                sid="InvalidateCache",
                actions=["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"],
                resources=[
                    f"arn:aws:cloudfront::{self.account}:distribution/{distribution.distribution_id}"
                ],
            )
        )

        self.role.add_to_policy(
            iam.PolicyStatement(
                sid="ReadStackOutputs",
                actions=["cloudformation:DescribeStacks"],
                resources=[
                    f"arn:aws:cloudformation:{self.region}:{self.account}:stack/MssPortfolio*/*"
                ],
            )
        )

        CfnOutput(self, "DeployRoleArn", value=self.role.role_arn)
