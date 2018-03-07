#!/bin/bash
echo "Enable IAM"
gcloud projects create $1
gcloud iam service-accounts create $1 --project $1
gcloud iam service-accounts keys create gce-$1-key.json --iam-account=$1@$1.iam.gserviceaccount.com --project $1
gcloud projects add-iam-policy-binding $1 --member="serviceAccount:$1@$1.iam.gserviceaccount.com" --role='roles/editor' --project $1

echo "Reconfigure the kubectl with new cluster data"
gcloud config set project $1

echo "Link billing to the account"
ACC_ID=`gcloud alpha billing accounts list|awk '{print $1}'|grep -v ID`
echo $ACC_ID
gcloud alpha billing projects link $1 --billing-account $ACC_ID

echo "Enable API's"
echo "Enable Google Cloud SQL API"
gcloud services enable sql-component.googleapis.com
echo "Enable Google Cloud Compute API"
gcloud services enable compute.googleapis.com
echo "Enable Google Cloud Kubernetes API"
gcloud services enable container.googleapis.com

echo "Setup Google Cloud Kubernetes"
cd kubernetes \
&& terraform init \
&& terraform plan -var "project=$1" -var "cluster_name=$1" -var "username=$1" -var "password=$1-123456789" \
&& terraform apply -var "project=$1" -var "cluster_name=$1" -var "username=$1" -var "password=$1-123456789"

echo "Deploy ES cluster on Kubernetes"
gcloud container clusters get-credentials $1 --zone europe-west1-b
kubectl create -f https://raw.githubusercontent.com/vbrinza/kubernetes-es-cluster/master/service-account.yaml
kubectl create -f https://raw.githubusercontent.com/vbrinza/kubernetes-es-cluster/master/es-discovery-svc.yaml
kubectl create -f https://raw.githubusercontent.com/vbrinza/kubernetes-es-cluster/master/es-master-rc.yaml
kubectl create -f https://raw.githubusercontent.com/vbrinza/kubernetes-es-cluster/master/es-data-rc.yaml
kubectl create -f https://raw.githubusercontent.com/vbrinza/kubernetes-es-cluster/master/es-client-rc.yml
kubectl create -f https://raw.githubusercontent.com/vbrinza/kubernetes-es-cluster/master/es-svc.yaml # exposes the service by public IP

echo "Deploy MySQL on Google Cloud SQL"
cd ../mysql && terraform init \
&& terraform plan  -var "name=$1" -var "project=$1" -var "db_name=$1" -var "user_name=xeval-9" \
&& terraform apply  -var "name=$1" -var "project=$1" -var "db_name=$1" -var "user_name=xeval-9"

echo "Add secrets"
cd .. && kubectl create secret generic cloudsql-oauth-credentials --from-file=credentials.json=gce-$1-key.json

echo "Addapt the application template"
cat <<EOF > application_deploy/app_deployment.yml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: eval
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: eval
    spec:
      containers:
      - name: eval
        image: pithagora/eval:0.0.1
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: prod
        - name: SPRING_DATASOURCE_URL
          value: jdbc:mysql://localhost:3306/$1?useUnicode=true&characterEncoding=utf8&useSSL=false
        ports:
        - containerPort: 8080
      - image: b.gcr.io/cloudsql-docker/gce-proxy:1.05
        name: cloudsql-proxy
        command: ["/cloud_sql_proxy", "--dir=/cloudsql",
                  "-instances=$1:europe-west1:$1=tcp:3306",
                  "-credential_file=/secrets/cloudsql/credentials.json"]
        volumeMounts:
          - name: cloudsql-oauth-credentials
            mountPath: /secrets/cloudsql
            readOnly: true
          - name: ssl-certs
            mountPath: /etc/ssl/certs
      volumes:
        - name: cloudsql-oauth-credentials
          secret:
            secretName: cloudsql-oauth-credentials
        - name: ssl-certs
          hostPath:
            path: /etc/ssl/certs
EOF

# echo "Deploy the application"
# kubectl apply -f application_deploy/app_deployment.yml
