output "vpc_id" {
value = aws_vpc.nodeproject-vpc.id
}

output "public1" {
    value = aws_subnet.public1.id
}

output "private1" {
    value = aws_subnet.private1.id
}

output "public2" {
    value = aws_subnet.public2.id
}

output "private2" {
    value = aws_subnet.private2.id
}