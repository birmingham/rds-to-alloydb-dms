# Consumed by the vpn and database/aws_rds stacks via terraform_remote_state.

output "region" {
  value = var.aws_region
}

output "vpc_id" {
  value = aws_vpc.source.id
}

output "vpc_cidr" {
  value = aws_vpc.source.cidr_block
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "route_table_id" {
  value = aws_route_table.private.id
}

output "vgw_id" {
  value = aws_vpn_gateway.vgw.id
}

output "vgw_asn" {
  value = var.aws_side_asn
}
