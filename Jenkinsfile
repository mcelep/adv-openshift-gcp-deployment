node('maven') {
    def IMAGE_NAME='openshift-tasks'    
    def PROJECT = 'o-tasks'
   stage('checkout source code'){
       git 'https://github.com/OpenShiftDemos/openshift-tasks'
   }
   stage('build application'){
        sh "mvn -DskipTests=true clean install"   
   }    
   stage('unit test'){
       sh 'mvn test'
   }
   
   stage('deploy'){
      def ret = sh(script: "oc get bc/${IMAGE_NAME} --ignore-not-found -o name -n ${PROJECT}", returnStdout: true)

        if(!ret){
            sh "oc new-build jboss-eap70-openshift:1.6 --binary=true --name ${IMAGE_NAME} --strategy=source -n ${PROJECT}"
        }
        sh "oc start-build ${IMAGE_NAME} -n ${PROJECT} --from-file=target/openshift-tasks.war --follow --wait"
        
        // Verify build
        openshiftVerifyBuild bldCfg: IMAGE_NAME, checkForTriggeredDeployments: 'false', namespace: PROJECT, verbose: 'false', waitTime: ''

        ret = sh(script: "oc get dc/${IMAGE_NAME} --ignore-not-found -o name -n ${PROJECT}", returnStdout: true)
        if(!ret){
            sh "oc new-app ${IMAGE_NAME} -n ${PROJECT}"
        }
        
        ret = sh(script: "oc get route/${IMAGE_NAME} --ignore-not-found -o name -n ${PROJECT}", returnStdout: true)
        if(!ret){
            sh "oc expose service ${IMAGE_NAME} -n ${PROJECT}"
        }
   }
   
   
}
