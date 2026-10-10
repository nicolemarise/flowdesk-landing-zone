# FlowDesk

FlowDesk is a customer support and operations management platform designed as the application layer for a production-style AWS infrastructure portfolio project.

## MVP features

- Support dashboard with operational KPIs
- Ticket creation
- Ticket status and priority tracking
- Ticket search and filtering
- Customer directory
- Team workload dashboard
- Basic reports view
- Responsive interface
- Browser-side demo data and interactions

## Project direction

The application will eventually be deployed on AWS using:

- VPC with public/private subnets across multiple Availability Zones
- Application Load Balancer
- EC2 Auto Scaling
- Amazon RDS Multi-AZ
- Amazon S3
- Amazon CloudWatch
- Terraform for Infrastructure as Code

The AWS infrastructure is intended to target 10K requests/hour, 99.99% uptime and lower operating costs through Auto Scaling and Multi-AZ failover. These are project targets and will be validated through testing rather than assumed.

## Run locally

Open `index.html` in a browser, or use VS Code Live Server / any simple local HTTP server.

## Next development stage

Replace demo browser data with a real backend and database, then containerise/deploy the application as part of the AWS project.
