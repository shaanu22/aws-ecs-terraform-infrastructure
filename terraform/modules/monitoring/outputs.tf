output "cpu_alarm_arn" {
  description = "ARN of the CPU alarm"
  value       = aws_cloudwatch_metric_alarm.ecs_cpu_high.arn
}

output "memory_alarm_arn" {
  description = "ARN of the memory alarm"
  value       = aws_cloudwatch_metric_alarm.ecs_memory_high.arn
}
