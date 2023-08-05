terraform {
  backend "remote" {
    organization = "vitalizing"
    workspaces {
      name = "prod_pyeth_proxy"
    }
  }
}
