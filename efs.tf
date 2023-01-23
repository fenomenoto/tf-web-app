resource "aws_security_group" "tf_efs_sg" {
  name        = "tf_efs_sg"
  description = "Communication-efs"
  vpc_id      = aws_vpc.tf_vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "tf-task2-sg"
  }
}
resource "aws_efs_file_system" "tf_efs" {
  creation_token = "tf-EFS-task2"
  tags = {
    Name = "awsEFS"
  }
}
resource "aws_efs_mount_target" "tf_mount" {
  depends_on = [
    aws_efs_file_system.tf_efs,
    aws_subnet.tf_subnet,
    aws_security_group.tf_efs_sg
  ]
  count = length(data.aws_availability_zones.available.names)
  file_system_id = aws_efs_file_system.tf_efs.id
  subnet_id      = aws_subnet.tf_subnet[count.index].id
  security_groups = [aws_security_group.tf_efs_sg.id]
}
resource "aws_efs_access_point" "efs_access" {
 depends_on = [
    aws_efs_file_system.tf_efs,
  ]
  file_system_id = aws_efs_file_system.tf_efs.id
}
resource "aws_instance" "tf_task2_ec2_webserver" {
depends_on = [
    aws_vpc.tf_vpc,
    aws_subnet.tf_subnet,
    aws_efs_file_system.tf_efs,
  ]
  count = 2
  ami           = "ami-084e8c05825742534"
  instance_type = "t2.micro"
  subnet_id      = aws_subnet.tf_subnet[count.index].id
  security_groups = [ aws_security_group.tf_efs_sg.id ]
  key_name = "kancho_key"
 
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/home/kancho/aws_web_app_keys/kancho_key.pem")
    host      = self.public_ip
  }

provisioner "remote-exec" {
    inline = [
        "sudo su <<END",
        "yum install git php httpd amazon-efs-utils -y",
        "rm -rf /var/www/html/*",
        "/usr/sbin/httpd",
        "efs_id=${aws_efs_file_system.tf_efs.id}",
        "accesspt_id=${aws_efs_access_point.efs_access.id}",
        "mount -t efs $efs_id:/ /var/www/html",
        "echo \"$efs_id /var/www/html efs _netdev,tls,accesspoint=$accesspt_id 0 0\" > /etc/fstab",
        "mount -a",
        "echo \"Hello World, from Kancho at $(hostname -f)\" > /var/www/html/index.html",
        "END",
    ]
  }
  tags = {
    Name = "tf_task2_ec2_webserver"
  }
}