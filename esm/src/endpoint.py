#!/usr/bin/python3

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

"""
# AutoEndpointRegistraionTool
"""

import os
import uuid
import json
import socket
import requests
import logging
from subprocess import run, PIPE

PORTAINER_URL = os.getenv('PORTAINER_URL')
PORTAINER_ADMIN_USERNAME = os.getenv('PORTAINER_ADMIN_USERNAME')
PORTAINER_ADMIN_PASSWORD = os.getenv('PORTAINER_ADMIN_PASSWORD')

class EdgeManagerToolException(Exception):
    """
    Exception handling class
    """
    pass

class EdgeManagerTool(object):
    """
    Main class for the module AutoEndpointRegistraionTool
    """
    def __init__(self, MODULE):
        self.modulepath = "{0}/{1}".format(os.getcwd(), MODULE)
        if not os.path.isdir(self.modulepath):
            os.makedirs(self.modulepath)
        self.log_file = "{0}/install.log".format(self.modulepath)
        self.log = logging.getLogger()
        fileHandler = logging.FileHandler(self.log_file, mode='a', encoding=None, delay=False)
        self.log.addHandler(fileHandler)
        self.log.setLevel(logging.INFO)

    def init_swarm(self):
        command = "docker swarm init --advertise-addr " + self.get_ip_address()
        self.log.info("Initialize docker swarm with command {0}".format(command))
        status = run(command, stdout=PIPE, stderr=PIPE, shell=True)
        if status.returncode:
            error = status.stderr.decode("utf-8")
            if "This node is already part of a swarm" not in error:
                raise EdgeManagerToolException(status.stdout + status.stderr, "Failed to initialise the swarm", command)

    def get_token(self):
        self.log.info("Get Token")
        headers = {"Content-Type": "application/json"}
        data = {"Username": PORTAINER_ADMIN_USERNAME, "Password": PORTAINER_ADMIN_PASSWORD}
        res = requests.post("{0}/api/auth".format(PORTAINER_URL), headers=headers, json=data)
        if res.status_code != 200:
            return res
        else:
            res_data = json.loads(res.text)
            return res_data["jwt"]

    def get_ip_address(self):
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.connect(("8.8.8.8", 80))
            ip_address = sock.getsockname()[0]
            sock.close()
        except Exception as error:
            raise EdgeManagerToolException("", "Failed to get the IP address", "")
        self.log.info("HOST IP address : {0}".format(ip_address))
        return ip_address
        
    def create_endpoint(self, jwt_token):
        endpoint_name = socket.gethostname()
        self.log.info("Create edge endpoint named {0} at {1}".format(endpoint_name, PORTAINER_URL))
        headers = {"Authorization": "Bearer {0}".format(jwt_token)}
        data = {"Name": endpoint_name, "EndpointType": "4", "URL": PORTAINER_URL}
        res = requests.post("{0}/api/endpoints".format(PORTAINER_URL), headers=headers, data=data)
        if res.status_code != 200:
            return res
        else:
            res_data = json.loads(res.text)
            return res_data["EdgeKey"]
        
    def deploy_emt_agents(self):
        self.log.info("deploy EMT agents")
        os.environ["no_proxy"] = "localhost"
        edge = "1"
        edge_uuid = str(uuid.uuid1())
        status = self.get_token()
        if type(status) == str:
            jwt_token = status
        else:
            raise EdgeManagerToolException(status.text, "Failed to get the endpoint token", "")
        status = self.create_endpoint(jwt_token)
        if type(status) == str:
            edge_key = status
        else:
            raise EdgeManagerToolException(status.text, "Failed to create the endpoint", "")
        os.environ["EDGE"] = edge
        os.environ["EDGE_ID"] = edge_uuid
        os.environ["EDGE_KEY"] = edge_key
        self.log.info("deploy emt stack to docker swarm cluster")
        command = "docker stack deploy -c /opt/esm/stacks/docker-stack.yml esm"
        status = run(command, stdout=PIPE, stderr=PIPE, shell=True)
        if status.returncode:
            raise EdgeManagerToolException(status.stdout + status.stderr, "Failes to deploy the EMT Agents", command)


if __name__ == "__main__":
    emt = EdgeManagerTool("esm")
    emt.init_swarm()
    emt.deploy_emt_agents()
