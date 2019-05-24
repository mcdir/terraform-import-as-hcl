# tf-import-hcl

This script imports a Terraform resource into `.tfstate` AND creates an HCL resource definition in `.tf` file.

The implementation is super naive and more than likely to have many bugs and corner cases.

For a proper solution, follow [hashicorp/terraform#15608](https://github.com/hashicorp/terraform/issues/15608).

## install

```bash
sudo snap install ruby          # version 2.6.3, or
sudo apt install -y ruby-bundler
bundle install
sudo ln -s $(pwd)/tf-import-hcl.rb /usr/local/bin/
```

## usage

`./tf-import-hcl.rb resource_type.resource_name resource_id [other parameters passed to Terraform]`

Example:

`./tf-import-hcl.rb datadog_monitor.test 244808`


Result:

```
$ cat datadog_monitor_test.tf
resource "datadog_monitor" "test" {
  query = "avg(last_15m):sum:chef.run.failure{*} by {host} >= 1"
  tags = ["*"]
  thresholds = { critical = "1.0" }
  *SNIPPED*
}

```

File created: `<resource_type>_<resource_name>.tf`
