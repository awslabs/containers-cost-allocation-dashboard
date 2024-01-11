# Post-Deployment

This document includes post-deployment steps.  
All sections are optional, but it's advised to review them.

## Share the Dashboard with Users

To share the dashboard with users, for them to be able to view it and create Analysis from it, see [this link](https://catalog.workshops.aws/awscid/en-US/dashboards/share).

## Create an Analysis from the Dashboard
 
Create an Analysis from the Dashboard, to edit it and create custom visuals:

1. Log in to QuickSight, navigate to "Dashboards" and click the `Containers Cost Allocation (CCA)` dashboard 
2. Go to step 9 in [this link](https://catalog.workshops.aws/awscid/en-US/dashboards/share) to allow "Save as" functionality for your user.  
Once done, go back to the dashboard and refresh the page (it's required to see the "Save as" icon).
3. On the top right part of the dashboard, click the "Save as" icon, name the Analysis, then click "SAVE".  
You'll now be navigated to the Analysis.
4. You can edit the Analysis as you wish, and save it again as a dashboard, by clicking the "Share" icon on the top right, then click "Publish dashboard".  
Please note that if you customize the dashboard, and would later like to update to a new dashboard version, you must maintain a separate dashboard.  
You can update a non-customized dashboard, then apply your customizations again on it.

## Tuning Schedules

All components in this solution that are running on schedule, have default schedule set, to simplify the deployment.  
Following are the schedules:

* Kubecost S3 Exporter CronJob default schedule: 00:00:00 UTC, daily
* Glue crawler schedule: 01:00:00 UTC, daily
* QuickSight dataset refresh schedule varies (changes in different deployments).  
The timezone for the QuickSight dataset refresh schedule is set based your selection when deploying the dashboard.

The Kubecost S3 Exporter CronJob schedule and the Glue crawler schedule, are based on cron expressions.  
Since cron expressions are always in UTC, the result may be that some components may be scheduled to run in a non-ideal order.  
This may result in data being available in the QuickSight dashboard, only 24 hours after it was uploaded to the S3 bucket.  
The most ideal schedule order is as follows:

1. All Kubecost S3 Exporter CronJobs on all clusters should run in a chosen schedule, possibly close to each other
2. The Glue crawler should run after all Kubecost S3 Exporter CronJobs finished running (possibly 1 hour gap would be a good idea)
3. The QuickSight dataset refresh should run after the Glue crawler finished running (possibly 1 hour gap would be a good idea)

It's advised to adjust these schedules as instructed above, using the relevant Terraform variables:

* For the Kubecost S3 Exporter CronJob schedule:  
Adjust the `kubecost_s3_exporter_cronjob_schedule` variable in the `kubecost_s3_exporter` Terraform reusable module.  
See [the `kubecost_s3_exporter` Terraform reusable module's variables.tf file](terraform/terraform-aws-cca/modules/kubecost_s3_exporter/variables.tf) for more information on this variable.
* For the Glue crawler schedule:  
Adjust the `glue_crawler_schedule` variable in the `pipeline` module.  
See [the `pipeline` Terraform reusable module's variables.tf file](terraform/terraform-aws-cca/modules/pipeline/variables.tf) for more information on this variable.
* For the QuickSight dataset refresh schedule:  
Follow [this document](https://docs.aws.amazon.com/quicksight/latest/user/refreshing-imported-data.html#schedule-data-refresh).  
Make sure you select "Full refresh".
