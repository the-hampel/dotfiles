c.ServerApp.allow_origin = '*'
c.IPKernelApp.pylab = 'inline'


c.ServerApp.ip = '*'

c.ServerApp.open_browser = False

# c.ServerApp.password = u'sha1:bc37000f2ea8:45e59eeb8ee2ce5b3e9510d4d5cbbb5eb8b229e5'
c.ServerApp.password = 'argon2:$argon2id$v=19$m=10240,t=10,p=8$YXfAW98EE4fvrfxMjl9Qgw$juiQLT3iBy1Bl95Sa2vUm9jMWO2qIKW8vBZtyMdxaaU'

c.ServerApp.port = 8378

c.NotebookNotary.db_file = u':memory:'

c.LabBuildApp.minimize = False
c.LabBuildApp.dev_build = False
