#!/usr/bin/env python3
"""
Generate architecture markdown with Mermaid diagrams from Terraform state.
"""
import json
import argparse
from datetime import datetime


def generate_resource_graph(resources):
    lines = ["graph TD"]
    nodes = {}
    edges = []

    for idx, resource in enumerate(resources):
        node_id = f"R{idx}"
        rtype = resource.get("type", "unknown")
        rname = resource.get("name", "unnamed")
        nodes[node_id] = f"{rtype}<br/>{rname}"
        lines.append(f"    {node_id}[{nodes[node_id]}]")

        for dep in resource.get("depends_on", []):
            for jdx, other in enumerate(resources):
                other_addr = f"{other.get('type', '')}.{other.get('name', '')}"
                if dep == other_addr:
                    edges.append(f"    R{jdx} --> {node_id}")

    lines.extend(edges)
    return "\n".join(lines)


def generate_network_topology(state):
    lines = ["graph LR"]
    vpc = None
    subnets = []

    for resource in state.get("resources", []):
        if resource.get("type") == "aws_vpc":
            vpc = resource
        elif resource.get("type") in ["aws_subnet", "aws_subnet.public", "aws_subnet.private"]:
            subnets.append(resource)

    if vpc:
        lines.append(f"    VPC[AWS VPC<br/>{vpc.get('name', '')}]")
        for idx, subnet in enumerate(subnets):
            lines.append(f"    SUB{idx}[Subnet<br/>{subnet.get('name', '')}]")
            lines.append(f"    VPC --> SUB{idx}")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    with open(args.state) as f:
        state = json.load(f)

    resources = state.get("resources", [])

    with open(args.output, "w") as f:
        f.write(f"# Architecture Documentation\n\n")
        f.write(f"_Auto-generated on {datetime.utcnow().isoformat()}Z_\n\n")

        f.write("## Resource Dependency Graph\n\n")
        f.write("```mermaid\n")
        f.write(generate_resource_graph(resources))
        f.write("\n```\n\n")

        f.write("## Network Topology\n\n")
        f.write("```mermaid\n")
        f.write(generate_network_topology(state))
        f.write("\n```\n\n")

        f.write("## Resources Summary\n\n")
        f.write("| Type | Name | Provider |\n")
        f.write("|------|------|----------|\n")
        for r in resources:
            f.write(f"| {r.get('type', '')} | {r.get('name', '')} | {r.get('provider', '')} |\n")


if __name__ == "__main__":
    main()
