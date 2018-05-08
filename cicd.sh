#!/bin/bash

set -ex

oc new-project cicd
oc new-app jenkins-persistent
oc rollout status dc/jenkins

# Create build job on jenkins
curl -XPOST "https://$(oc get route/jenkins --template='{{.spec.host}}')/createItem?name=openshift-tasks" -H "Authorization: Bearer $(oc whoami -t)" --data-binary @jenkins-job.xml -H "Content-Type:text/xml"


# Build job
curl -XPOST "https://$(oc get route/jenkins --template='{{.spec.host}}')/job/openshift-tasks/build" -H "Authorization: Bearer $(oc whoami -t)"

oc new-project o-tasks
# Make sure o-tasks project can access openshift namespace
oc policy add-role-to-group \
    system:image-puller \
    system:serviceaccounts:o-tasks \
    -n openshift

# Grant jenkins account rights
oc policy add-role-to-user edit system:serviceaccount:cicd:jenkins -n o-tasks
oc policy add-role-to-user edit system:serviceaccount:cicd:default -n o-tasks


