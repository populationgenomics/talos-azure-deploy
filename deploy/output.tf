
output "job_id" {
  value = azurerm_container_app_job.job.id
}

output "job_identity" {
  value = azurerm_container_app_job.job.identity
}
