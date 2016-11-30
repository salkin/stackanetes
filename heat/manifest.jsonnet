local kpm = import "kpm.libjsonnet";

function(
  params={}
)

kpm.package({
  package: {
    name: "stackanetes/heat",
    expander: "jinja2",
    author: "Niklas Wik",
    version: "0.1.0",
    description: "nova",
    license: "Apache 2.0",
  },

  variables: {
    deployment: {
      engine: "docker",
      control_node_label: "openstack-control-plane",
      compute_node_label: "openstack-compute-node",

      replicas: 1,

      image: {
        base: "quay.io/stackanetes/stackanetes-%s:barcelona",

        init: $.variables.deployment.image.base % "kolla-toolbox",
        db_sync: "docker.io/nwik/heat-api:3.0.0",
        api: "docker.io/nwik/heat-api:3.0.0",
      },
    },

    network: {
      ip_address: "{{ .IP }}",
      external_ips: [],
      minion_interface_name: "eno1",
      dns:  {
        servers: ["10.3.0.10"],
        kubernetes_domain: "cluster.local",
        other_domains: "",
      },

      port: {
	api: 8004,
      },

      ingress: {
        enabled: true,
        host: "%s.openstack.cluster",
        port: 30080,

        named_host: {
          api: $.variables.network.ingress.host % "orchestration",
        }
      },
    },
    heat: {
     api_url: "http://heat-api:8004"
    },

    database: {
      address: "mariadb",
      port: 3306,
      root_user: "root",
      root_password: "password",

      heat_user: "heat",
      heat_password: "password",
      heat_database_name: "heat",
      heat_api_database_name: "heat_api"
    },

    keystone: {
      auth_uri: "http://keystone-api:5000",
      auth_url: "http://keystone-api:35357",
      admin_user: "admin",
      admin_password: "password",
      admin_project_name: "admin",
      admin_region_name: "RegionOne",
      domain_name: "default",
      tenant_name: "admin",
      auth: "{'auth_url':'%s', 'username':'%s','password':'%s','project_name':'%s','domain_name':'%s'}" % [$.variables.keystone.auth_url, $.variables.keystone.admin_user, $.variables.keystone.admin_password, $.variables.keystone.admin_project_name, $.variables.keystone.domain_name],

    },

    rabbitmq: {
      address: "rabbitmq",
      admin_user: "rabbitmq",
      admin_password: "password",
      port: 5672
    },

    memcached: {
      address: "memcached:11211",
    },
    
    misc: {
      debug: false,
      workers: 8,
    },
  },

  resources: [
    // Config maps.
    {
      file: "configmaps/init.sh.yaml.j2",
      template: (importstr "templates/configmaps/init.sh.yaml.j2"),
      name: "heat-initsh",
      type: "configmap",
    },
    {
      file: "configmaps/db-sync.sh.yaml.j2",
      template: (importstr "templates/configmaps/db-sync.sh.yaml.j2"),
      name: "heat-dbsyncsh",
      type: "configmap",
    },
    {
      file: "configmaps/heat.conf.yaml.j2",
      template: (importstr "templates/configmaps/heat.conf.yaml.j2"),
      name: "heat-heatconf",
      type: "configmap",
    },


    // Init.
    {
      file: "jobs/init.yaml.j2",
      template: (importstr "templates/jobs/init.yaml.j2"),
      name: "heat-init",
      type: "job",
    },
    {
      file: "jobs/db-sync.yaml.j2",
      template: (importstr "templates/jobs/db-sync.yaml.j2"),
      name: "heat-db-sync",
      type: "job",
    },

    // Deployments.
    {
      file: "api/deployment.yaml.j2",
      template: (importstr "templates/api/deployment.yaml.j2"),
      name: "heat-api",
      type: "deployment",
    },


    // Services.
    {
      file: "api/service.yaml.j2",
      template: (importstr "templates/api/service.yaml.j2"),
      name: "heat-api",
      type: "service",
    },

    // Ingresses.
    if $.variables.network.ingress.enabled == true then
      {
        file: "api/ingress.yaml.j2",
        template: (importstr "templates/api/ingress.yaml.j2"),
        name: "heat-api",
        type: "ingress",
      },

  ],

  deploy: [
    {
      name: "$self",
    },
  ]
}, params)
