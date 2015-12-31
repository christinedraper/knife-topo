name             'testapp'
maintainer       'ThirdWave Insights LLC'
maintainer_email 'christine_draper@thirdwaveinsights.com'
license          'Apache v2.0'
description      'Installs/Configures test application'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.2.1'
depends			 'mongodb', '~> 0.16'
depends      'nodejs', '~> 2.4'