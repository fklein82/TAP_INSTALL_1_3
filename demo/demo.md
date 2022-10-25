# PLAY
## How to pitch and make a TAP demo

[![N|Solid](https://img.shields.io/badge/VMware-231f20?style=for-the-badge&logo=VMware&logoColor=white)](https://tanzu.vmware.com/application-platform)

## Start pitch

- PPT | Introduction

## Developer experience demo
- Explore: http://tap-gui.tanzu.fklein.me/catalog?filters%5Bkind%5D=component&filters%5Buser%5D=all

- Accelerators: VScode pluggin or http://tap-gui.tanzu.fklein.me/create?filters%5Bkind%5D=template&filters%5Buser%5D=all

- App Deployment: Live View with VScode pluggin or command tanzu apps workload create -f $TANZU_APP_FILES_PATH/config/workload.yaml -y

- Follow: 
tanzu apps workload tail tanzu-app-deploy -n dev --since 1m
tanzu apps workload get tanzu-app-deploy -n dev

- Access App & Infos : (Status / Logs / Live View) http://tap-gui.tanzu.fklein.me/catalog/default/component/tanzu-java-web-app/workloads

- Access APIs
http://tap-gui.tanzu.fklein.me/api-docs?filters%5Bkind%5D=api&filters%5Buser%5D=all
http://api-portal.tanzu.fklein.me/apis

## Supply Chain demo

## Cloud Native Buildpacks demo

## Deployment to prod demo

## clean

kp clusterbuilder patch default --stack old