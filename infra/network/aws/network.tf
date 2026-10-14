data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "source" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name}-vpc" }
}

# Private subnets only: no internet gateway, no NAT. The only way in or out
# is the VPN to Google Cloud.
resource "aws_subnet" "private" {
  count             = length(var.aws_private_subnet_cidrs)
  vpc_id            = aws_vpc.source.id
  cidr_block        = var.aws_private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { Name = "${var.name}-private-${count.index}" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.source.id
  tags   = { Name = "${var.name}-private" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpn_gateway" "vgw" {
  vpc_id          = aws_vpc.source.id
  amazon_side_asn = var.aws_side_asn
  tags            = { Name = "${var.name}-vgw" }
}

# BGP-learned GCP routes (tools subnet + AlloyDB PSA range) land in the
# route table automatically.
resource "aws_vpn_gateway_route_propagation" "private" {
  vpn_gateway_id = aws_vpn_gateway.vgw.id
  route_table_id = aws_route_table.private.id
}
