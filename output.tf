output "id" {
  description = "an identifier for the resource with format"
  value       = google_compute_instance.default.id
}

output "instance_id" {
  description = " The server-assigned unique identifier of this instance."
  value       = google_compute_instance.default.instance_id
}



output "metadata_fingerprint" {
  description = " The metadata_fingerprint identifier of this instance."
  value       = google_compute_instance.default.metadata_fingerprint
}
