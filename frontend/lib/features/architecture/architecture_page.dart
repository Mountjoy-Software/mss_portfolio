import 'package:flutter/material.dart';

import '../../core/widgets.dart';

const _tiers = <({String title, String detail, List<String> services})>[
  (
    title: 'Edge',
    detail:
        'One CloudFront distribution fronts everything, so the browser talks to a '
        'single origin and never issues a cross-origin request. Static paths hit S3; '
        '/api/* is a second behaviour pointed at the load balancer with caching off.',
    services: ['Route 53', 'CloudFront', 'ACM'],
  ),
  (
    title: 'Static frontend',
    detail:
        'The Flutter web bundle lives in a private S3 bucket reached only through an '
        'Origin Access Control signature. Deep links work because a CloudFront '
        'Function rewrites extensionless paths to index.html. It is scoped to the '
        'static behaviour, so a real 404 from the API stays a 404.',
    services: ['S3', 'CloudFront Functions'],
  ),
  (
    title: 'API',
    detail:
        'FastAPI on ECS Fargate behind an Application Load Balancer. The load '
        'balancer security group admits only the CloudFront origin-facing prefix '
        'list, so the API cannot be reached by going around the CDN.',
    services: ['ECS Fargate', 'ALB', 'ECR'],
  ),
  (
    title: 'State',
    detail:
        'A single DynamoDB table with a TTL attribute, holding rate-limit counters '
        'keyed by a salted hash of the caller rather than an address. On-demand '
        'billing means it costs nothing while nobody is here.',
    services: ['DynamoDB', 'Secrets Manager'],
  ),
  (
    title: 'Delivery',
    detail:
        'GitHub Actions authenticates by OIDC federation and assumes a role scoped '
        'to this repository on main. There are no long-lived AWS keys anywhere in '
        'the pipeline.',
    services: ['GitHub Actions', 'IAM OIDC', 'CDK'],
  ),
];

const _decisions = <({String choice, String why})>[
  (
    choice: 'No NAT gateway',
    why:
        'Tasks run in public subnets with a security group that accepts traffic '
        'only from the load balancer. A NAT gateway would add about \$32/month for '
        'egress this design does not need, and gateway endpoints keep S3 and '
        'DynamoDB traffic off the internet for free.',
  ),
  (
    choice: 'Static assets on S3, not in a container',
    why:
        'Serving a compiled SPA from a Fargate task means paying for compute to '
        'hand back files that never change. CloudFront caches them at the edge '
        'instead, and the container only answers requests that need code to run.',
  ),
  (
    choice: 'Immutable image tags',
    why:
        'Each deploy builds an image tagged with the commit SHA, and CDK deploys '
        'that exact tag. Rolling back means redeploying a known tag instead of '
        'hoping :latest still points where you expect.',
  ),
  (
    choice: 'Prompt caching on the assistant',
    why:
        'The system prompt carrying the work history is built once at import and '
        'cached for an hour, so repeat visitors read from cache at a tenth of the '
        'input price instead of paying full rate for the same context.',
  ),
];

class ArchitecturePage extends StatelessWidget {
  const ArchitecturePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ContentColumn(
      children: [
        const SectionHeading(
          'How this site is built',
          subtitle: 'The infrastructure is part of the point.',
        ),
        for (final (i, tier) in _tiers.indexed) ...[
          _TierCard(index: i + 1, tier: tier),
          if (i < _tiers.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Icon(
                Icons.arrow_downward,
                size: 18,
                color: theme.colorScheme.outline,
              ),
            ),
        ],
        const SizedBox(height: 40),
        const SectionHeading(
          'Why it is built this way',
          subtitle: 'The tradeoffs behind the boxes above.',
        ),
        for (final decision in _decisions)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(decision.choice, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  decision.why,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.index, required this.tier});

  final int index;
  final ({String title, String detail, List<String> services}) tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$index',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tier.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(tier.detail, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 14),
                  TagRow(tier.services),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
