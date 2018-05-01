#!/bin/bash

set -ex

gcloud compute instances create bastion --zone us-east1-b \
 --boot-disk-size=20GB \
 --machine-type=n1-standard-1 \
 --network=openshift \
 --subnet=flat \
 --image=rhel-openshift \
 --tags=external-ssh


gcloud compute disks create disc-master1 disc-master2 disc-master3 disc-node1 disc-node2 disc-infra1 disc-infra2  --zone us-east1-b --size=100GB
#gcloud compute disks create disc-master1  --zone us-east1-b --size=100GB

gcloud compute instances create master1 --zone us-east1-b \
 --boot-disk-size=20GB \
 --disk=name=disc-master1 \
 --machine-type=n1-standard-1 \
 --network=openshift \
 --subnet=flat \
 --image=rhel-openshift \
 --tags=ssh-internal,master,node

gcloud compute instances create master2 --zone us-east1-b \
 --boot-disk-size=20GB \
 --disk=name=disc-master2 \
 --machine-type=n1-standard-1 \
 --network=openshift \
 --subnet=flat \
 --image=rhel-openshift \
 --tags=ssh-internal,master,node

gcloud compute instances create master3 --zone us-east1-b \
 --boot-disk-size=20GB \
 --disk=name=disc-master3 \
 --machine-type=n1-standard-1 \
 --network=openshift \
 --subnet=flat \
 --image=rhel-openshift \
 --tags=ssh-internal,master,node


gcloud compute instances create node1 --zone us-east1-b \
 --boot-disk-size=20GB \
 --disk=name=disc-node1 \
 --machine-type=n1-standard-1 \
 --network=openshift \
 --subnet=flat \
 --image=rhel-openshift \
 --tags=ssh-internal,node

gcloud compute instances create infra1 --zone us-east1-b \
 --boot-disk-size=20GB \
 --disk=name=disc-infra1 \
 --machine-type=n1-standard-1 \
 --network=openshift \
 --subnet=flat \
 --image=rhel-openshift \
 --tags=ssh-internal,node

gcloud compute instances create infra2 --zone us-east1-b \
 --boot-disk-size=20GB \
 --disk=name=disc-infra2 \
 --machine-type=n1-standard-1 \
 --network=openshift \
 --subnet=flat \
 --image=rhel-openshift \
 --tags=ssh-internal,node

gcloud compute --project=openshift-201311 instance-groups unmanaged create master --zone=us-east1-b
gcloud compute --project=openshift-201311 instance-groups unmanaged add-instances master --zone=us-east1-b --instances=master1
gcloud compute --project=openshift-201311 instance-groups unmanaged add-instances master --zone=us-east1-b --instances=master2,master3
gcloud compute --project=openshift-201311 instance-groups unmanaged set-named-ports master --named-ports=http:80,https:443,https:8443 --zone us-east1-b

gcloud compute --project=openshift-201311 instance-groups unmanaged create infra --zone=us-east1-b
gcloud compute --project=openshift-201311 instance-groups unmanaged add-instances infra --zone=us-east1-b --instances=infra1
gcloud compute --project=openshift-201311 instance-groups unmanaged add-instances infra --zone=us-east1-b --instances=infra2
gcloud compute --project=openshift-201311 instance-groups unmanaged set-named-ports infra --named-ports=http:80,https:443,https:8443 --zone us-east1-b


# Give access rights to VM on gcp api's
gcloud compute instances set-service-account bastion --scopes=default,cloud-platform,compute-rw,storage-rw --zone=us-east1-b
gcloud compute instances set-service-account master1 --scopes=default,cloud-platform,compute-rw,storage-rw --zone=us-east1-b
gcloud compute instances set-service-account node1 --scopes=default,cloud-platform,compute-rw,storage-rw --zone=us-east1-b
gcloud compute instances set-service-account infra1 --scopes=default,cloud-platform,compute-rw,storage-rw --zone=us-east1-b


gcloud compute instances set-service-account infra2 --scopes=default,cloud-platform,compute-rw,storage-rw --zone=us-east1-b
gcloud compute instances set-service-account master2 --scopes=default,cloud-platform,compute-rw,storage-rw --zone=us-east1-b
gcloud compute instances set-service-account master3 --scopes=default,cloud-platform,compute-rw,storage-rw --zone=us-east1-b

### Internal Load Balancing setup for Masters
gcloud compute health-checks create https master-health-check --port 443

gcloud compute addresses create lb-master-internal-ip-address \
    --region us-east1 --subnet flat

# Create internal load balancer for masters
gcloud compute backend-services create master-internal-lb \
        --load-balancing-scheme internal \
        --region us-east1 \
        --health-checks master-health-check
gcloud compute backend-services add-backend master-internal-lb \
	--instance-group master-internal \
	--instance-group-zone us-east1-b \
	--region us-east1

gcloud compute forwarding-rules create master-int-lb-forwarding-rule \
    --address lb-master-internal-ip-address \
    --load-balancing-scheme internal \
    --backend-service master-internal-lb \
    --ports 443 \
    --region us-east1 \
    --subnet flat

### External Load Balancing setup for Masters


gcloud compute backend-services create master-lb \
        --load-balancing-scheme external \
        --global \
        --health-checks master-health-check \
        --protocol tcp \
        --port-name https 

gcloud compute backend-services add-backend master-lb \
        --instance-group master \
        --instance-group-zone us-east1-b \
        --global

gcloud compute addresses create lb-master-public-ip \
    --global

gcloud compute target-tcp-proxies create tcp-proxy-master-backend-service --backend-service=master-lb

gcloud compute forwarding-rules create master-lb-forwarding-rule \
    --address lb-master-public-ip \
    --ports 443 \
    --target-tcp-proxy tcp-proxy-master-backend-service \
    --global

# Create external load balancer for infra nodes
gcloud compute health-checks create https infra-health-check
gcloud compute backend-services create infra-lb \
        --load-balancing-scheme external \
        --global \
        --health-checks infra-health-check \ 
        --protocol tcp\
        --port-name https
gcloud compute backend-services add-backend infra-lb \
        --instance-group infra \
	--instance-group-zone us-east1-b \
        --global

gcloud compute target-tcp-proxies create tcp-proxy-infra-backend-service --backend-service=infra-lb

gcloud compute forwarding-rules create infra-lb-forwarding-lb \
    --ports 443 \
    --target-tcp-proxy tcp-proxy-infra-backend-service \
    --global
