# Bucket and per-stack prefix are supplied by scripts/tf.sh at init.
terraform {
  backend "gcs" {}
}
