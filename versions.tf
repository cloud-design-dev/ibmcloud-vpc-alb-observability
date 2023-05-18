terraform {
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.50.0"
    }
logdna = {
      source  = "logdna/logdna"
      version = "1.14.2"

    }
  }
}