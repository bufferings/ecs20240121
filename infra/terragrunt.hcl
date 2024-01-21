remote_state {
  backend = "s3"
  config = {
    bucket  = "ecs20240121"
    key     = "${path_relative_to_include()}/terraform.tfstate"
    encrypt = true
    region  = "ap-northeast-1"
  }
}
