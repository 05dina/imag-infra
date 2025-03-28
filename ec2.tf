
data "aws_ami" "amazon_linux_latest" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-*", "AL*-ARM_64-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

module "ssh-sg" {
  source = "terraform-aws-modules/security-group/aws//modules/ssh"

  name        = "${terraform.workspace}-ssh-sg"
  description = "SSH access"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
}

module "personal_key" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name           = "${terraform.workspace}-ssh-key"
  public_key         = file("~/.ssh/id_rsa.pub")
  create_private_key = false
}

module "ec2" {
  source = "terraform-aws-modules/ec2-instance/aws"

  create                      = true
  key_name                    = module.personal_key.key_pair_name
  name                        = "${terraform.workspace}-bastion"
  ami                         = data.aws_ami.amazon_linux_latest.id
  instance_type               = "t4g.nano"
  associate_public_ip_address = true
  subnet_id                   = module.vpc.public_subnets[0]

  vpc_security_group_ids = compact([
    module.ssh-sg.security_group_id,
    try(module.rds-sg.security_group_id, null)
  ])

  user_data = <<-EOF
#!/bin/bash
  yum install -y nc tmux
  amazon-linux-extras install -y postgresql14 ansible2
EOF

  tags = {
    Terraform   = "true"
    Environment = terraform.workspace
  }

  depends_on = [
    module.rds
  ]
}
