resource "aws_lb" "tf-lb" {
    depends_on = [
    aws_vpc.tf_vpc,
    aws_subnet.tf_subnet,
    aws_efs_file_system.tf_efs,
  ]
  name               = "te-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.tf_efs_sg.id}"]
  subnets            = "${aws_subnet.tf_subnet.*.id}"

  tags = {
    Environment = "production"
  }
}
resource "aws_lb_target_group" "tf-target-grp" {
    depends_on =[
        aws_lb.tf-lb,
        aws_instance.tf_task2_ec2_webserver,
    ]
  name     = "target-grp-lb"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.tf_vpc.id}"
}

resource "aws_lb_target_group_attachment" "tf-lb-attach" {
    depends_on = [
        aws_lb_target_group.tf-target-grp
    ]
  count = length(aws_instance.tf_task2_ec2_webserver)
  target_group_arn = "${aws_lb_target_group.tf-target-grp.arn}"
  target_id        = aws_instance.tf_task2_ec2_webserver[count.index].id 
  port             = 80
}
resource "aws_lb_listener" "ports-listening" {
     depends_on = [
        aws_lb_target_group.tf-target-grp
    ]
  load_balancer_arn = "${aws_lb.tf-lb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.tf-target-grp.arn}"
  }
}

resource "aws_lb_listener_rule" "tf-lb-rule" {
    depends_on = [
       aws_lb_listener.ports-listening
    ]
  listener_arn = "${aws_lb_listener.ports-listening.arn}"


  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.tf-target-grp.arn}"
  }

  condition {
    path_pattern {
      values = ["/static/*"]
    }
  }
}
resource "null_resource" "website"  {
  depends_on = [
      aws_lb_listener_rule.tf-lb-rule,  
    ]
    
  provisioner "local-exec" {
       command = "echo \"Kancho's WebApp Web link:\" http://${aws_lb.tf-lb.dns_name}/"
  }
}

resource "aws_cloudwatch_metric_alarm" "tf_cloudwatch" {
  alarm_name                = "tf_cloudwatch"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  threshold                 = "1000"
  alarm_description         = "Request rate has exceeded 1000/2sec"
  insufficient_data_actions = []

  metric_query {
    id = "m1"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = "120"
      stat        = "Sum"
      unit        = "Count"

      dimensions = {
      LoadBalancer = "app/web"
      }
    }
  }
}
