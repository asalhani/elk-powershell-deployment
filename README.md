# ELK Stack Installer

### Tech

ELK Installer is going to work with the following tools:

* [ElasticSearch](https://www.elastic.co/) - Search and analyze your data in real time.
* [Logstash](https://www.elastic.co/logstash) - Centralize, transform & stash your data
* [Kibana](https://www.elastic.co/kibana) - visualize your Elasticsearch data and navigate the Elastic Stack
* [Curator](https://www.elastic.co/guide/en/elasticsearch/client/curator/current/about.html#:~:text=Elasticsearch%20Curator%20helps%20you%20curate,this%20actionable%20list%20as%20needed.) - manage, your Elasticsearch indices and snapshots
* [Filebeat](https://www.elastic.co/beats/filebeat) - Aggregate logs from different sources
* [NSSM](https://nssm.cc/) - Non-Sucking Service Manager
* 
### Download Pre-requriests files

| Tool | Download link |
| ------ | ------ |
| ElasticSearch | [https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.8.1-windows-x86_64.zip] |
| Filebeat | [https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.8.1-windows-x86_64.zip] |
| Kibana | [https://artifacts.elastic.co/downloads/kibana/kibana-7.8.1-windows-x86_64.zip] |
| Logstash | [https://artifacts.elastic.co/downloads/logstash/logstash-7.8.1.zip] |
| Curator | [https://packages.elastic.co/curator/5/windows/elasticsearch-curator-5.8.1-amd64.zip] |
| NSSM | [https://nssm.cc/release/nssm-2.24.zip] |

### Installation

Collect all the downloaded files listed in [prerequisite] section into a folder
```
c:\elk-installation-files
```

Open [settings.json] file and update the following keys:

| Key | Value |
| ------ | ------ |
| installationFilesFolder | Path to the folder contains all prerequisite zip files |
| runRootFolder | The root folder where the application will be installed and run from ``` c:\elk```|
| inspectionTenantsRootLogPath | Path to the directory where tenant logs is stored ``` D:\\Inspection\\AdminPortal\\Tenants_logs\\LABTOP\\logs``` |
| adminPortalRootLogPath | Path to the directory where admin portal logs is stored ``` D:\\Inspection\\AdminPortal\\AdminPortal_websiste\\logs``` |

```
Run Powershell as Admin
```
Run the manage script:
```powershell
.\Manage-Elk.ps1
```

Enter the operation you want:
| Operation | Description |
| ------ | ------ |
| install | Install the ELK stack  |
| uninstall | Unnstall the ELK stack (Delete all Windows services & File system)  |
| start | Start all ELK windows services (ElasticSearch, Logstash, Kibana, Filebeat)  |
| stop | Stop all ELK windows services (ElasticSearch, Logstash, Kibana, Filebeat) |


