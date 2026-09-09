#!/usr/bin/env python3
import aws_cdk as cdk

from stacks.api import ApiStack
from stacks.cicd import CicdStack
from stacks.data import DataStack
from stacks.site import SiteStack

app = cdk.App()

ctx = app.node.try_get_context
env = cdk.Environment(account=ctx("account"), region=ctx("region"))
domain = ctx("domain")
api_domain = ctx("api_subdomain")
zone_id = ctx("hosted_zone_id")

data = DataStack(app, "MssPortfolioData", env=env, termination_protection=True)

api = ApiStack(
    app,
    "MssPortfolioApi",
    env=env,
    table=data.table,
    repository=data.repository,
    anthropic_secret=data.anthropic_secret,
    admin_secret=data.admin_secret,
    domain=domain,
    api_domain=api_domain,
    zone_id=zone_id,
    image_tag=ctx("image_tag") or "latest",
    origin_prefix_list=ctx("cloudfront_origin_prefix_list"),
)

site = SiteStack(
    app,
    "MssPortfolioSite",
    env=env,
    domain=domain,
    api_domain=api_domain,
    zone_id=zone_id,
)

CicdStack(
    app,
    "MssPortfolioCicd",
    env=env,
    github_repo=ctx("github_repo"),
    site_bucket=site.bucket,
    distribution=site.distribution,
    repository=data.repository,
)

site.add_dependency(api)

app.synth()
