# Install Terraform on macOS

Use `brew` to install Terraform on macOS </br>
See [Install Terraform on macOS](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli#install-terraform)

# Install AWS CLI on macOS

Use `brew` to install AWS CLI on macOS </br>

```
$> brew install awscli
$> aws configure
   // provide:
   // IAM user Access Key ID
   // IAM user Secret Access Key
   // AWS region
   // Output (json)
```

The following files are created:

```
~/.aws/credentials
~/.aws/config
```

A `default` profile has been created in these files. Manually you can add other profiles.
