#!/usr/bin/env python
import pykube
import json
import sh
import os

# extract nodePort data from kubectl services and merge it with the IP from minikube services 
# to expose as environment variables like those you'd have access to in kubernetes
# NOTE: this requires a port be named

class AutoVivification(dict):
	'''Implementation of perl's autovivification feature'''
	def __getitem__(self, item):
		try:
			return dict.__getitem__(self, item)
		except KeyError:
			value = self[item] = type(self)()
			return value

homedir = os.path.expanduser('~')
api = pykube.HTTPClient(pykube.KubeConfig.from_file("%s/.kube/config" % (homedir)))
services = pykube.Service.objects(api).filter(namespace="default")

data = AutoVivification()
for i in services.all():
  for x in i.obj.viewitems():
      if 'spec' in x:
          if 'ports' in x[1].keys():
              for p in x[1]['ports']:
                  if 'nodePort' in p.keys():
                      data[str(i)][p['name']] = p['nodePort']

ipdata = AutoVivification()
for i in data.keys():
    x = sh.minikube("service", i, "--url")
    if x.split("\n")[0]:
        ipdata[i] = x.split("\n")[0].split("/")[2].split(":")[0]

filename = '%s/.minienv' %  homedir
target = open(filename, 'w')
print "Writing to: %s" % filename
print "################################"
for i in data.keys():
	for a in data[i].keys():
		portstring = "%s_SERVICE_PORT_%s=%s" % (i.upper(), a.upper(), data[i][a])
		portstring = portstring.replace("-", "_")
		print "export %s" % (portstring)
		target.write("export %s\n" % portstring)
	hoststring = "%s_SERVICE_HOST=%s" % (i.upper(), ipdata[i])
	hoststring = hoststring.replace("-", "_")
	print "export %s" % (hoststring)
	target.write("export %s\n" % hoststring)
target.close()
print "################################"
print "to use all these variables run:"
print "source %s" % filename
