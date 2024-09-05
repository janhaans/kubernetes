resource "aws_iam_user" "example" {
    name = var.user_name
    path = "/"

    tags = {
        Name        = "Anna-Maria"
    }
}