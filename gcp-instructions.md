# Gemini Enterprise (`geapp`) Static Outbound IP via Agent Gateway — Permissions & Manual Deployment Guide

- **Target Project:** `genai-dev-454121` (projectNumber: `615780545876`, orgId: `517908812890`)
- **Active Principal:** `admin@raulramos.altostrat.com`
- **Auth Token Status:** `AUTHENTICATED`
- **Gateway & Cloud NAT Region:** `us-central1` (paired with `geapp` location: `global`)
- **Gemini Enterprise App (`geapp`):** `main test app` (Engine ID: `main-test-app_1784407513868`)
- **Remote MCP Endpoint:** `https://mcp.35.186.182.189.sslip.io/mcp`
- **Reserved Static Outbound IP:** `35.232.82.164` (`hello-mcp-static-agw-ip`)

---

## Part 1: Least-Privilege Permissions, APIs, Service Agents & Org Policies (Live Status)

### 1A. Required GCP Service APIs (9 APIs)

| API Service Name | Title | Status | Purpose |
| :--- | :--- | :--- | :--- |
| `compute.googleapis.com` | Compute Engine API | **ENABLED** | VPC network, PSC subnet, Static External IP, Cloud Router, Cloud NAT, PSC Network Attachment |
| `discoveryengine.googleapis.com` | Discovery Engine API (Gemini Enterprise) | **ENABLED** | Inspect/patch geapp Engine, create/activate Custom MCP DataConnector, invoke :streamAssist |
| `networkservices.googleapis.com` | Network Services API | **ENABLED** | Create/manage AgentConnectivityTemplate (ALL_TRAFFIC) and AgentGateway (AGENT_TO_ANYWHERE) |
| `networksecurity.googleapis.com` | Network Security API | **ENABLED** | Create/manage AuthzPolicy (REQUEST_AUTHZ) attached to the Agent Gateway |
| `serviceextensions.googleapis.com` | Service Extensions API | **ENABLED** | Create/manage IAP V2 AuthzExtension (iap.googleapis.com) |
| `iap.googleapis.com` | Identity-Aware Proxy API | **ENABLED** | Evaluate IAP V2 egress authorization (iap.googleapis.com/resources.egressViaIAP) |
| `agentregistry.googleapis.com` | Agent Registry API | **ENABLED** | Register remote MCP server endpoint and tool schema (services / mcpServers) |
| `orgpolicy.googleapis.com` | Organization Policy API | **ENABLED** | Inspect (and if enforced, override) Custom MCP and IAM v3 policy binding constraints |
| `cloudresourcemanager.googleapis.com` | Cloud Resource Manager API | **ENABLED** | Resolve project number/organization ID and manage project service agent IAM bindings |

### 1B. Least-Privilege Deployer IAM Permissions (Granular — Avoid Generalist Roles)

> **Security Principle:** Do **not** grant generalist roles such as `roles/owner`, `roles/editor`, `roles/compute.admin`, `roles/networkservices.admin`, or `roles/iam.securityAdmin`. Below is the minimal set of granular permissions required across each component and their current status for your active account.

#### 1. Project Metadata, API Enablement & Service Identity Setup

- **Restrictive Predefined Role Alternative:** `roles/serviceusage.serviceUsageAdmin + roles/resourcemanager.projectIamAdmin (setup only)`

| Permission | Status | Scope / Operation |
| :--- | :--- | :--- |
| `resourcemanager.projects.get` | **GRANTED** | Read project number and organization ancestry |
| `serviceusage.services.list` | **GRANTED** | Check enabled GCP service APIs (preflight/instructions) |
| `serviceusage.services.enable` | **GRANTED** | Enable required GCP service APIs (deploy) |
| `serviceusage.services.use` | **GRANTED** | Provision Google-managed service identities (deploy) |
| `resourcemanager.projects.getIamPolicy` | **GRANTED** | Inspect project IAM bindings for service agents |
| `resourcemanager.projects.setIamPolicy` | **GRANTED** | Bind serviceAgent roles (only needed if not pre-bound) |

#### 2. Organization Policy Inspection & Conditional Overrides

- **Restrictive Predefined Role Alternative:** `roles/orgpolicy.policyViewer (or roles/orgpolicy.policyAdmin only if policies are enforced)`

| Permission | Status | Scope / Operation |
| :--- | :--- | :--- |
| `orgpolicy.policy.get` | **GRANTED** | Inspect effective org policy constraints (preflight) |
| `orgpolicy.policies.create` | **GRANTED** | Create project-level org policy override (only if enforced) |
| `orgpolicy.policies.update` | **GRANTED** | Update project-level org policy override (only if enforced) |

#### 3. VPC, PSC Subnet, Static IP, Cloud NAT & PSC Network Attachment

- **Restrictive Predefined Role Alternative:** `roles/compute.networkAdmin (scoped to networking only — NOT roles/compute.admin)`

| Permission | Status | Scope / Operation |
| :--- | :--- | :--- |
| `compute.networks.create` | **GRANTED** | Create custom-mode VPC network |
| `compute.networks.get` | **GRANTED** | Describe VPC network |
| `compute.networks.updatePolicy` | **GRANTED** | Attach PSC subnet and Cloud Router to VPC |
| `compute.networks.delete` | **GRANTED** | Delete VPC network (undeploy) |
| `compute.subnetworks.create` | **GRANTED** | Create PSC subnet with Private Google Access |
| `compute.subnetworks.get` | **GRANTED** | Describe PSC subnet |
| `compute.subnetworks.use` | **GRANTED** | Attach PSC subnet to PSC Network Attachment |
| `compute.subnetworks.delete` | **GRANTED** | Delete PSC subnet (undeploy) |
| `compute.addresses.create` | **GRANTED** | Reserve regional Static External IPv4 address |
| `compute.addresses.get` | **GRANTED** | Read reserved Static External IPv4 address |
| `compute.addresses.use` | **GRANTED** | Bind reserved Static IP to Cloud NAT gateway |
| `compute.addresses.delete` | **GRANTED** | Release Static External IPv4 address (undeploy) |
| `compute.routers.create` | **GRANTED** | Create Cloud Router in gateway region |
| `compute.routers.get` | **GRANTED** | Describe Cloud Router and Cloud NAT config |
| `compute.routers.update` | **GRANTED** | Create/update/delete Cloud NAT gateway on Cloud Router |
| `compute.routers.use` | **GRANTED** | Attach Cloud Router to VPC network |
| `compute.routers.delete` | **GRANTED** | Delete Cloud Router (undeploy) |
| `compute.networkAttachments.create` | **GRANTED** | Create ACCEPT_AUTOMATIC PSC Network Attachment |
| `compute.networkAttachments.get` | **GRANTED** | Describe PSC Network Attachment & connected endpoints |
| `compute.networkAttachments.delete` | **GRANTED** | Delete PSC Network Attachment (undeploy) |

#### 4. Agent Connectivity Template & Agent Gateway

- **Restrictive Predefined Role Alternative:** `roles/agentgateway.admin (scoped to Agent Gateway — NOT roles/networkservices.admin)`

| Permission | Status | Scope / Operation |
| :--- | :--- | :--- |
| `networkservices.agentConnectivityTemplates.create` | **GRANTED** | Create AgentConnectivityTemplate (ALL_TRAFFIC) |
| `networkservices.agentConnectivityTemplates.get` | **GRANTED** | Describe AgentConnectivityTemplate |
| `networkservices.agentConnectivityTemplates.update` | **GRANTED** | Update/import AgentConnectivityTemplate |
| `networkservices.agentConnectivityTemplates.delete` | **GRANTED** | Delete AgentConnectivityTemplate (undeploy) |
| `networkservices.agentGateways.create` | **GRANTED** | Create AGENT_TO_ANYWHERE MCP Agent Gateway |
| `networkservices.agentGateways.get` | **GRANTED** | Describe Agent Gateway |
| `networkservices.agentGateways.update` | **GRANTED** | Update/import Agent Gateway |
| `networkservices.agentGateways.delete` | **GRANTED** | Delete Agent Gateway (undeploy) |

#### 5. Service Extensions IAP V2 AuthzExtension

- **Restrictive Predefined Role Alternative:** `roles/serviceextensions.admin (or custom role with authzExtensions.* only)`

| Permission | Status | Scope / Operation |
| :--- | :--- | :--- |
| `serviceextensions.authzExtensions.create` | **GRANTED (role)** | Create IAP V2 AuthzExtension (iap.googleapis.com) |
| `serviceextensions.authzExtensions.get` | **GRANTED (role)** | Describe AuthzExtension |
| `serviceextensions.authzExtensions.update` | **GRANTED (role)** | Update/import AuthzExtension |
| `serviceextensions.authzExtensions.delete` | **GRANTED (role)** | Delete AuthzExtension (undeploy) |

#### 6. Network Security AuthzPolicy

- **Restrictive Predefined Role Alternative:** `roles/networksecurity.authzPolicyAdmin (scoped to AuthzPolicy only)`

| Permission | Status | Scope / Operation |
| :--- | :--- | :--- |
| `networksecurity.authzPolicies.create` | **GRANTED** | Create REQUEST_AUTHZ AuthzPolicy targeting Gateway |
| `networksecurity.authzPolicies.get` | **GRANTED** | Describe AuthzPolicy |
| `networksecurity.authzPolicies.update` | **GRANTED** | Update/import AuthzPolicy |
| `networksecurity.authzPolicies.delete` | **GRANTED** | Delete AuthzPolicy (undeploy) |

#### 7. Agent Registry MCP Server Catalog

- **Restrictive Predefined Role Alternative:** `roles/agentregistry.admin (scoped to Agent Registry services & MCP servers)`

| Permission | Status | Scope / Operation |
| :--- | :--- | :--- |
| `agentregistry.services.create` | **GRANTED** | Register remote MCP server URL & tool-spec schema |
| `agentregistry.services.get` | **GRANTED** | Describe Agent Registry service |
| `agentregistry.services.update` | **GRANTED** | Update Agent Registry service URL & tool-spec |
| `agentregistry.services.delete` | **GRANTED** | Delete Agent Registry service (undeploy) |
| `agentregistry.mcpServers.list` | **GRANTED** | List projected McpServer resources |
| `agentregistry.mcpServers.get` | **GRANTED** | Describe projected McpServer resource |

#### 8. IAM v3 Unified Access Policy & Policy Binding (IAP Egress)

- **Restrictive Predefined Role Alternative:** `Custom role / IAM v3 AccessPolicy & PolicyBinding permissions (NOT roles/iam.securityAdmin)`

| Permission | Status | Scope / Operation |
| :--- | :--- | :--- |
| `iam.accessPolicies.create` | **GRANTED (role)** | Create IAM v3 AccessPolicy (iap.googleapis.com/resources.egressViaIAP) |
| `iam.accessPolicies.get` | **GRANTED (role)** | Describe IAM v3 AccessPolicy |
| `iam.accessPolicies.update` | **GRANTED (role)** | Update IAM v3 AccessPolicy |
| `iam.accessPolicies.delete` | **GRANTED (role)** | Delete IAM v3 AccessPolicy (undeploy) |
| `iam.policyBindings.create` | **GRANTED (role)** | Bind IAM v3 AccessPolicy to target GCP project |
| `iam.policyBindings.get` | **GRANTED (role)** | Describe IAM v3 PolicyBinding |
| `iam.policyBindings.delete` | **GRANTED (role)** | Delete IAM v3 PolicyBinding (undeploy) |

#### 9. Gemini Enterprise (Discovery Engine) App, Custom MCP Connector & Assistant

- **Restrictive Predefined Role Alternative:** `roles/discoveryengine.admin (scoped to Discovery Engine only)`

| Permission | Status | Scope / Operation |
| :--- | :--- | :--- |
| `discoveryengine.engines.get` | **GRANTED** | Describe existing geapp Engine |
| `discoveryengine.engines.list` | **GRANTED** | Resolve geapp Engine by display name |
| `discoveryengine.engines.update` | **GRANTED** | Patch defaultEgressAgentGateway and dataStoreIds on Engine |
| `discoveryengine.collections.create` | **GRANTED** | Create collection for Custom MCP connector |
| `discoveryengine.collections.get` | **GRANTED** | Describe Custom MCP collection |
| `discoveryengine.collections.delete` | **GRANTED** | Delete Custom MCP collection (undeploy) |
| `discoveryengine.dataConnectors.create` | **GRANTED (role)** | Provision custom_mcp DataConnector (:setUpDataConnector) |
| `discoveryengine.dataConnectors.get` | **GRANTED** | Describe custom_mcp DataConnector state |
| `discoveryengine.dataConnectors.update` | **GRANTED** | Activate actionConfig (use_agent_gateway_egress=true) |
| `discoveryengine.dataStores.get` | **GRANTED** | Inspect _mcp_data store attached to Engine |
| `discoveryengine.assistants.get` | **GRANTED** | Send test prompts via default_assistant:streamAssist (send) |

**Deployer Permission Summary:** **69 granted** | **0 missing** | **0 unverified** (Total: 69 permissions)

#### Least-Privilege Custom Role Command (Recommended over Predefined Roles)

```bash
gcloud iam roles create staticAgentGatewayDeployer \
  --project=genai-dev-454121 \
  --title="Static IP Agent Gateway & MCP Deployer" \
  --description="Least-privilege role to deploy Agent Gateway + Cloud NAT static IP for Gemini Enterprise MCP" \
  --permissions="resourcemanager.projects.get,serviceusage.services.list,serviceusage.services.enable,serviceusage.services.use,resourcemanager.projects.getIamPolicy,resourcemanager.projects.setIamPolicy,orgpolicy.policy.get,orgpolicy.policies.create,orgpolicy.policies.update,compute.networks.create,compute.networks.get,compute.networks.updatePolicy,compute.networks.delete,compute.subnetworks.create,compute.subnetworks.get,compute.subnetworks.use,compute.subnetworks.delete,compute.addresses.create,compute.addresses.get,compute.addresses.use,compute.addresses.delete,compute.routers.create,compute.routers.get,compute.routers.update,compute.routers.use,compute.routers.delete,compute.networkAttachments.create,compute.networkAttachments.get,compute.networkAttachments.delete,networkservices.agentConnectivityTemplates.create,networkservices.agentConnectivityTemplates.get,networkservices.agentConnectivityTemplates.update,networkservices.agentConnectivityTemplates.delete,networkservices.agentGateways.create,networkservices.agentGateways.get,networkservices.agentGateways.update,networkservices.agentGateways.delete,serviceextensions.authzExtensions.create,serviceextensions.authzExtensions.get,serviceextensions.authzExtensions.update,serviceextensions.authzExtensions.delete,networksecurity.authzPolicies.create,networksecurity.authzPolicies.get,networksecurity.authzPolicies.update,networksecurity.authzPolicies.delete,agentregistry.services.create,agentregistry.services.get,agentregistry.services.update,agentregistry.services.delete,agentregistry.mcpServers.list,agentregistry.mcpServers.get,iam.accessPolicies.create,iam.accessPolicies.get,iam.accessPolicies.update,iam.accessPolicies.delete,iam.policyBindings.create,iam.policyBindings.get,iam.policyBindings.delete,discoveryengine.engines.get,discoveryengine.engines.list,discoveryengine.engines.update,discoveryengine.collections.create,discoveryengine.collections.get,discoveryengine.collections.delete,discoveryengine.dataConnectors.create,discoveryengine.dataConnectors.get,discoveryengine.dataConnectors.update,discoveryengine.dataStores.get,discoveryengine.assistants.get"

gcloud projects add-iam-policy-binding genai-dev-454121 \
  --member="user:admin@raulramos.altostrat.com" \
  --role="projects/genai-dev-454121/roles/staticAgentGatewayDeployer"
```

### 1C. Required Google-Managed Service Agent & Runtime SPIFFE Bindings

| Service Agent / Principal | Role / Permission | Status | Purpose |
| :--- | :--- | :--- | :--- |
| `service-615780545876@gcp-sa-discoveryengine.iam.gserviceaccount.com` | `roles/discoveryengine.serviceAgent` | **GRANTED** | Allows Gemini Enterprise to manage collections, connectors & egress |
| `service-615780545876@gcp-sa-discoveryengine.iam.gserviceaccount.com` | `roles/agentregistry.TempServiceAgent` | **MISSING** | Allows Gemini Enterprise to read MCP server schemas in Agent Registry |
| `service-615780545876@gcp-sa-agentgateway.iam.gserviceaccount.com` | `roles/agentgateway.serviceAgent` | **GRANTED** | Allows Agent Gateway to attach PSC endpoints to the Network Attachment |
| `service-615780545876@gcp-sa-networkservices.iam.gserviceaccount.com` | `roles/networkservices.serviceAgent` | **MISSING** | Allows Network Services to provision Secure Web Proxy & connectivity |
| `service-615780545876@gcp-sa-iap.iam.gserviceaccount.com` | `roles/iap.egressServiceAgent` | **MISSING** | Allows IAP V2 AuthzExtension to evaluate IAM v3 egress policies |
| `SPIFFE: .../engines/main-test-app_1784407513868/.../core_assistant` | `iap.googleapis.com/resources.egressViaIAP` | **GRANTED (BOUND)** | Authorizes the `geapp` `default_assistant` workload identity to egress via IAP V2 to registered MCP servers |

### 1D. Organization Policy Constraints (Must Not Block Custom MCP or IAM v3)

| Constraint Name | Current Status | Requirement |
| :--- | :--- | :--- |
| `iam.managed.disableAccessPolicyBinding` | **ENABLED (NOT BLOCKING)** | Must be NOT enforced (enforce: false) so IAM v3 PolicyBinding can attach the IAP AccessPolicy to the project |
| `discoveryengine.SkipCustomMcpRestriction` | **ENABLED (NOT BLOCKING)** | Must be NOT enforced (enforce: false) to allow Custom MCP connectors in Gemini Enterprise |
| `discoveryengine.managed.disableCustomMcpServerConnector` | **ENABLED (NOT BLOCKING)** | Must be NOT enforced (enforce: false) to allow creating custom_mcp DataConnectors |
| `discoveryengine.managed.allowedEgressFqdns` | **ENABLED (NOT BLOCKING)** | Must be NOT enforced (or explicitly allow the mcp.<IP>.sslip.io FQDN) for outbound MCP egress |
| `discoveryengine.managed.allowedDataSources` | **ENABLED (NOT BLOCKING)** | Must be NOT enforced (or explicitly allow custom_mcp) in Discovery Engine |

---

## Part 2: Step-by-Step Manual Deployment Guide Using the GCP Console

This guide walks through manually deploying the complete Static Outbound IP Agent Gateway architecture in the Google Cloud Console using the exact settings from your configuration file (`project=genai-dev-454121`, `gateway_region=us-central1`, `geapp=main test app`).

### Phase 1: Enable APIs, Verify Service Agents & Check Org Policies

1. **Enable Required APIs (`APIs & Services > Library`)**
   - Open: <https://console.cloud.google.com/apis/library?project=genai-dev-454121>
   - Search for and click **Enable** on each of the following APIs:
     - Compute Engine API (`compute.googleapis.com`)
     - Discovery Engine API (`discoveryengine.googleapis.com`)
     - Network Services API (`networkservices.googleapis.com`)
     - Network Security API (`networksecurity.googleapis.com`)
     - Service Extensions API (`serviceextensions.googleapis.com`)
     - Identity-Aware Proxy API (`iap.googleapis.com`)
     - Agent Registry API (`agentregistry.googleapis.com`)
     - Organization Policy API (`orgpolicy.googleapis.com`)
     - Cloud Resource Manager API (`cloudresourcemanager.googleapis.com`)

2. **Grant Google-Managed Service Agent Roles (`IAM & Admin > IAM`)**
   - Open: <https://console.cloud.google.com/iam-admin/iam?project=genai-dev-454121>
   - Check **"Include Google-provided role grants"** at the top right of the IAM table.
   - Click **Grant Access** to add any missing service agent role bindings:
     - Principal: `service-615780545876@gcp-sa-discoveryengine.iam.gserviceaccount.com`
       - Roles: `Discovery Engine Service Agent` (`roles/discoveryengine.serviceAgent`), `Agent Registry Temp Service Agent` (`roles/agentregistry.TempServiceAgent`)
     - Principal: `service-615780545876@gcp-sa-agentgateway.iam.gserviceaccount.com`
       - Role: `Agent Gateway Service Agent` (`roles/agentgateway.serviceAgent`)
     - Principal: `service-615780545876@gcp-sa-networkservices.iam.gserviceaccount.com`
       - Role: `Network Services Service Agent` (`roles/networkservices.serviceAgent`)
     - Principal: `service-615780545876@gcp-sa-iap.iam.gserviceaccount.com`
       - Role: `IAP Egress Service Agent` (`roles/iap.egressServiceAgent`)
   - *Note:* If a service agent email does not exist yet, initialize it once in Cloud Shell:
     `gcloud beta services identity create --service=<api>.googleapis.com --project=genai-dev-454121`

3. **Verify Organization Policies (`IAM & Admin > Organization Policies`)**
   - Open: <https://console.cloud.google.com/iam-admin/orgpolicies/list?project=genai-dev-454121>
   - Filter for each constraint below; if any is enforced, click it -> **Manage policy** -> **Override parent's policy** -> set Enforcement to **Off** (`enforce: false`) -> **Set policy**:
     - `iam.managed.disableAccessPolicyBinding`
     - `discoveryengine.SkipCustomMcpRestriction`
     - `discoveryengine.managed.disableCustomMcpServerConnector`
     - `discoveryengine.managed.allowedEgressFqdns`
     - `discoveryengine.managed.allowedDataSources`

### Phase 2: Create VPC, PSC Subnet, Static External IP, Cloud NAT & PSC Attachment

> **Important Regional Alignment:** Because your Gemini Enterprise app is in `global`, **all** networking and Agent Gateway resources **must** be created in `us-central1`.

1. **Create Custom VPC Network & PSC Subnet (`VPC network > VPC networks`)**
   - Open: <https://console.cloud.google.com/networking/networks/add?project=genai-dev-454121>
   - **Name:** `hello-mcp-static-agw-vpc`
   - **Subnet creation mode:** Select **Custom**
   - Under **New subnet**, configure:
     - **Name:** `hello-mcp-static-agw-psc-subnet`
     - **Region:** `us-central1`
     - **IP stack type:** `IPv4 (single-stack)`
     - **IPv4 range:** `192.168.10.0/28` (must be `/28` or larger for PSC Network Attachment)
     - **Private Google Access:** Select **On**
   - Click **Done** on the subnet, leave firewall rules unchecked, and click **Create**.

2. **Reserve Regional Static External IPv4 Address (`VPC network > IP addresses`)**
   - Open: <https://console.cloud.google.com/networking/addresses/add?project=genai-dev-454121>
   - **Name:** `hello-mcp-static-agw-ip`
   - **Network Service Tier:** `Premium`
   - **IP version:** `IPv4`
   - **Type:** `Regional`
   - **Region:** `us-central1`
   - **Attached to:** `None` (will be assigned to Cloud NAT in the next step)
   - Click **Reserve** and copy the allocated IPv4 address (`35.232.82.164`).

3. **Create Cloud Router & Cloud NAT Gateway (`Network Services > Cloud NAT`)**
   - Open: <https://console.cloud.google.com/net-services/nat/add?project=genai-dev-454121>
   - **Gateway name:** `hello-mcp-static-agw-nat`
   - **NAT type:** `Public`
   - **Cloud Router:**
     - **Network:** `hello-mcp-static-agw-vpc`
     - **Region:** `us-central1`
     - Select **Create new router** -> Name: `hello-mcp-static-agw-router` -> click **Create**
   - **Cloud NAT mapping:** `All subnets (primary and secondary IP ranges)`
   - **Cloud NAT IP addresses:**
     - Select **Manual** (do **not** use Automatic or traffic will use ephemeral IPs)
     - **IP address 1:** Select `hello-mcp-static-agw-ip` (`35.232.82.164`)
   - Expand **Advanced configurations** -> under **Logging**, select **Translation and errors**.
   - Click **Create**.

4. **Create PSC Network Attachment (`Network Services > Private Service Connect`)**
   - Open: <https://console.cloud.google.com/net-services/psc/list?tab=networkAttachments&project=genai-dev-454121>
   - Click **Create network attachment**:
     - **Name:** `hello-mcp-static-agw-psc-attachment`
     - **Region:** `us-central1`
     - **Network:** `hello-mcp-static-agw-vpc`
     - **Subnetworks:** Select `hello-mcp-static-agw-psc-subnet`
     - **Connection preference:** Select **Accept connections automatically (Accept all)**
   - Click **Create**.

### Phase 3: Register the Remote MCP Server in Agent Registry

1. **Verify Remote MCP Server HTTPS Endpoint**
   - Ensure your MCP server is running behind HTTPS with a publicly trusted CA certificate at `https://mcp.35.186.182.189.sslip.io/mcp` (Agent Gateway's Secure Web Proxy uses TLS SNI inspection and rejects plain HTTP or bare IP URLs with HTTP 404 `default_denied`).

2. **Create Agent Registry Service Entry**
   - Open Agent Registry in the Console (or click the **Activate Cloud Shell** `>_` icon in the top-right Console toolbar):
     - **Location:** `us-central1`
     - **Service ID:** `mcp-hello-static`
     - **Display Name:** `Hello MCP Static (Agent Gateway)`
     - **Protocol Binding:** `JSONRPC`
     - **Endpoint URL:** `https://mcp.35.186.182.189.sslip.io/mcp`
     - **MCP Tool Spec:** JSON schema defining `hello` and `hello_from_ip`

```bash
cat <<'EOF' > /tmp/toolspec.json
{
  "tools": [
    {
      "name": "hello",
      "description": "Say hello to someone from the remote MCP server.",
      "isReadOnly": true,
      "isDestructive": false,
      "isIdempotent": true,
      "isOpenWorld": false,
      "inputSchema": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string",
            "title": "Name",
            "default": "World"
          }
        }
      }
    },
    {
      "name": "hello_from_ip",
      "description": "Say hello and report the incoming client IP address and proxy headers seen by the MCP server.",
      "isReadOnly": true,
      "isDestructive": false,
      "isIdempotent": true,
      "isOpenWorld": false,
      "inputSchema": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string",
            "title": "Name",
            "default": "World"
          }
        }
      }
    }
  ]
}
EOF
gcloud agent-registry services create mcp-hello-static \
  --location=us-central1 \
  --display-name="Hello MCP Static (Agent Gateway)" \
  --interfaces="protocolBinding=JSONRPC,url=https://mcp.35.186.182.189.sslip.io/mcp" \
  --mcp-server-spec-type=tool-spec \
  --mcp-server-spec-content=/tmp/toolspec.json \
  --project=genai-dev-454121
```

### Phase 4: Provision AgentConnectivityTemplate (`ALL_TRAFFIC`) & Agent Gateway

1. **Create the `AgentConnectivityTemplate` (`vpcEgress: ALL_TRAFFIC`)**
   - Navigate to **Network Services > Agent Gateway** (or run the YAML import in **Cloud Shell**):
     - **Name:** `hello-mcp-static-agw-act` (Location: `us-central1`)
     - **Access Path:** `AGENT_TO_ANYWHERE`
     - **Deployment Model:** `CENTRALIZED`
     - **Network Attachment:** `projects/genai-dev-454121/regions/us-central1/networkAttachments/hello-mcp-static-agw-psc-attachment`
     - **VPC Egress:** `ALL_TRAFFIC` (routes all public internet MCP calls into your PSC subnet)

```bash
cat <<'EOF' > /tmp/act.yaml
accessPath: AGENT_TO_ANYWHERE
name: projects/615780545876/locations/us-central1/agentConnectivityTemplates/hello-mcp-static-agw-act
deploymentModel: CENTRALIZED
egressNetworkConfig:
  networkAttachment: projects/genai-dev-454121/regions/us-central1/networkAttachments/hello-mcp-static-agw-psc-attachment
  vpcEgress: ALL_TRAFFIC
EOF
gcloud alpha network-services agent-connectivity-templates import hello-mcp-static-agw-act \
  --location=us-central1 --source=/tmp/act.yaml --project=genai-dev-454121
```

2. **Create the `AgentGateway` (`AGENT_TO_ANYWHERE`)**
   - Configure the Agent Gateway in `us-central1` linked to the Connectivity Template and Registry:

```bash
cat <<'EOF' > /tmp/agw.yaml
name: hello-mcp-static-agw-gateway
protocols:
  - MCP
googleManaged:
  governedAccessPath: AGENT_TO_ANYWHERE
agentConnectivityTemplate: projects/615780545876/locations/us-central1/agentConnectivityTemplates/hello-mcp-static-agw-act
registries:
  - //agentregistry.googleapis.com/projects/genai-dev-454121/locations/us-central1
EOF
gcloud alpha network-services agent-gateways import hello-mcp-static-agw-gateway \
  --location=us-central1 --source=/tmp/agw.yaml --project=genai-dev-454121
```

### Phase 5: Configure IAP V2 AuthzExtension, AuthzPolicy & IAM v3 Access Policy

1. **Create the Service Extensions `AuthzExtension` (`Network Services > Service Extensions`)**
   - Open: <https://console.cloud.google.com/net-services/service-extensions/list?project=genai-dev-454121>
   - **Name:** `hello-mcp-static-agw-iap-ext` | **Region:** `us-central1`
   - **Service:** `iap.googleapis.com` | **Fail Open:** `false` | **Timeout:** `1s` | **Metadata:** `iapPolicyVersion: V2`

```bash
cat <<'EOF' > /tmp/authz-ext.yaml
name: hello-mcp-static-agw-iap-ext
service: iap.googleapis.com
failOpen: false
timeout: 1s
metadata:
  iapPolicyVersion: V2
EOF
gcloud service-extensions authz-extensions import hello-mcp-static-agw-iap-ext \
  --location=us-central1 --source=/tmp/authz-ext.yaml --project=genai-dev-454121
```

2. **Create the Network Security `AuthzPolicy` (`Network Security > Authorization Policies`)**
   - Open: <https://console.cloud.google.com/net-security/authz-policies/list?project=genai-dev-454121>
   - **Name:** `hello-mcp-static-agw-authz-policy` | **Region:** `us-central1`
   - **Target Resource:** `projects/genai-dev-454121/locations/us-central1/agentGateways/hello-mcp-static-agw-gateway`
   - **Policy Profile:** `REQUEST_AUTHZ` | **Action:** `CUSTOM`
   - **AuthzExtension:** `projects/genai-dev-454121/locations/us-central1/authzExtensions/hello-mcp-static-agw-iap-ext`

```bash
cat <<'EOF' > /tmp/authz-policy.yaml
name: hello-mcp-static-agw-authz-policy
target:
  resources:
    - projects/genai-dev-454121/locations/us-central1/agentGateways/hello-mcp-static-agw-gateway
policyProfile: REQUEST_AUTHZ
action: CUSTOM
customProvider:
  authzExtension:
    resources:
      - projects/genai-dev-454121/locations/us-central1/authzExtensions/hello-mcp-static-agw-iap-ext
EOF
gcloud network-security authz-policies import hello-mcp-static-agw-authz-policy \
  --location=us-central1 --source=/tmp/authz-policy.yaml --project=genai-dev-454121
```

3. **Create IAM v3 `AccessPolicy` & `PolicyBinding` for the `geapp` SPIFFE Identity**
   - Authorize your Gemini Enterprise `default_assistant` workload identity to egress via IAP to any MCP service registered in Agent Registry (`destination.is_registered == true`):

```bash
cat <<'EOF' > /tmp/iap_rules.json
[
  {
    "description": "allow geapp main-test-app_1784407513868 assistant to any registered service",
    "effect": "ALLOW",
    "principals": [
      "principal://agents.global.org-517908812890.system.id.goog/resources/discoveryengine/projects/615780545876/locations/global/engines/main-test-app_1784407513868/assistants/default_assistant/agents/default/core_assistant",
      "principal://agents.global.org-517908812890.system.id.goog/resources/aiplatform/projects/615780545876/locations/global/collections/default_collection/engines/main-test-app_1784407513868/assistants/default_assistant"
    ],
    "operation": {"permissions": ["iap.googleapis.com/resources.egressViaIAP"]},
    "conditions": {"iap.googleapis.com": {"expression": "destination.is_registered == true"}}
  }
]
EOF
gcloud iam access-policies create hello-mcp-static-agw-iap-policy \
  --location=global --display-name=hello-mcp-static-agw-iap-policy \
  --details-rules=/tmp/iap_rules.json --project=genai-dev-454121
gcloud iam policy-bindings create hello-mcp-static-agw-iap-binding \
  --location=global \
  --policy="projects/genai-dev-454121/locations/global/accessPolicies/hello-mcp-static-agw-iap-policy" \
  --target-resource="//cloudresourcemanager.googleapis.com/projects/genai-dev-454121" \
  --project=genai-dev-454121
```

### Phase 6: Wire Agent Gateway & Custom MCP Connector in Gemini Enterprise Console

1. **Bind Default Egress Agent Gateway to the Gemini Enterprise App**
   - Open: <https://console.cloud.google.com/gen-app-builder/engines?project=genai-dev-454121>
   - Select your existing Gemini Enterprise App: `main test app` (Engine ID: `main-test-app_1784407513868`, Location: `global`).
   - In **App Settings > Agent Gateway / Egress**, set **Default Egress Agent Gateway** to:
     `projects/genai-dev-454121/locations/us-central1/agentGateways/hello-mcp-static-agw-gateway`

2. **Create & Activate the Custom MCP Connector (`REGISTRY_MCP`)**
   - Open: <https://console.cloud.google.com/gen-app-builder/data-stores?project=genai-dev-454121>
   - Click **Create Data Store / Add Connector** -> select **Custom MCP Server (`custom_mcp`)**:
     - **Location:** `global`
     - **Collection / Connector ID:** `hello-mcp-static-agw`
     - **Display Name:** `Hello MCP Static (Agent Gateway)`
     - **Connector Mode:** `FEDERATED` (Entity: `mcp_data`)
     - **MCP Server Source:** `REGISTRY_MCP`
     - **Registry MCP Server Name:** `projects/genai-dev-454121/locations/us-central1/mcpServers/<MCP_SERVER_ID>`
     - **Instance URI:** `https://mcp.35.186.182.189.sslip.io/mcp`
     - **Auth Type:** `NO_AUTH`
     - **Use Agent Gateway Egress (`use_agent_gateway_egress`):** `true` (Enabled)
     - **Agent Gateway Engine:** `projects/genai-dev-454121/locations/global/collections/default_collection/engines/main-test-app_1784407513868`
   - Attach the resulting `hello-mcp-static-agw_mcp_data` Data Store to your `main-test-app_1784407513868` App (and detach any older non-Agent-Gateway MCP Data Stores targeting `https://mcp.35.186.182.189.sslip.io/mcp`).

### Phase 7: Verify Static Outbound IP in Console Preview & Cloud Logging

1. **Test from Gemini Enterprise Web App / Console Preview**
   - Open your `main test app` app preview in the Console and ask:
     `Call hello_from_ip for Raul and tell me what IP address the MCP server sees`
   - Confirm that the returned IP address matches your reserved Cloud NAT Static IP: **`35.232.82.164`**

2. **Verify Egress & SNAT in Cloud Logging (`Logs Explorer`)**
   - Open: <https://console.cloud.google.com/logs/query?project=genai-dev-454121>
   - **Agent Gateway & IAP Authz trace query:**
     `resource.type="networkservices.googleapis.com/Gateway" AND resource.labels.location="us-central1"`
   - **Cloud NAT Static IP translation query:**
     `resource.type="nat_gateway" AND resource.labels.gateway_name="hello-mcp-static-agw-nat"`

3. **Lock Down the Remote MCP Server Firewall (Recommended)**
   - Restrict inbound TCP port `443` on your remote MCP server firewall to source CIDR `35.232.82.164/32` so only requests routed through your Agent Gateway + Cloud NAT can reach the MCP server.
