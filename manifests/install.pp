class marsnat::install (
  $naticaversion = hiera('marsnatversion', 'master'),
  ) {
  notify{"Loading marsnat::install.pp; naticaversion=${naticaversion}":}

  ensure_resource('package', ['git', ], {'ensure' => 'present'})
  include augeas

  user { 'devops' :
    ensure     => 'present',
    comment    => 'For python virtualenv and running mars.',
    managehome => true,
    password   => '$1$Pk1b6yel$tPE2h9vxYE248CoGKfhR41',  # tada"Password"
    system     => true,
  }

#!dq_host: ${hiera('dq_host')}
#!dq_port: ${hiera('dq_port')}
#!dq_loglevel: ${hiera('dq_loglevel')}
#!natica_host: ${hiera('natica_host')}
#!valley_host: ${hiera('valley_host')}
#!mars_host: ${hiera('mars_host')}
#!mars_port: ${hiera('mars_port')}
#!tadaversion: ${hiera('tadaversion')}
#!dataqversion: ${hiera('dataqversion')}
#!marsversion: ${hiera('marsversion')}
  file {  '/etc/mars/from-hiera.yaml': 
    ensure  => 'present',
    replace => true,
    content => "---

naticaversion: ${naticaversion}
",
    group   => 'root',
    mode    => '0774',
  }
  
  file { '/etc/mars/django_local_settings.py':
    replace => true,
    source  => hiera('localnatica'),
  } 

  yumrepo { 'ius':
    descr      => 'ius - stable',
    baseurl    => 'http://dl.iuscommunity.org/pub/ius/stable/CentOS/6/x86_64/',
    enabled    => 1,
    gpgcheck   => 0,
    priority   => 1,
    mirrorlist => absent,
  }
  -> Package<| provider == 'yum' |>

  file { [ '/var/run/mars', '/var/log/mars', '/etc/mars', '/var/mars']:
    ensure => 'directory',
    mode   => '0777',
  } ->
  vcsrepo { '/opt/mars' :
    ensure   => latest,
    provider => git,
    source   => 'https://github.com/NOAO/marsnat.git',
    #!revision => 'master',
    revision => "${naticaversion}",
    owner    => 'devops',
    group    => 'devops',
    require  => User['devops'],
    notify   => Exec['start mars'],
    } ->
  package{ ['postgresql', 'postgresql-devel', 'expect'] : } ->
  class { 'python' :
    version    => 'python36u',
    pip        => 'present',
    dev        => 'present',
    virtualenv => 'absent',  # 'present',
    gunicorn   => 'absent',
    } ->
  file { '/usr/bin/python3':
    ensure => 'link',
    target => '/usr/bin/python3.6',
    } ->
  python::pyvenv  { '/opt/mars/venv':
    version  => '3.6',
    owner    => 'devops',
    group    => 'devops',
    require  => [ User['devops'], ],
  } ->
  python::requirements  { '/opt/mars/requirements.txt':
    virtualenv => '/opt/mars/venv',
    owner    => 'devops',
    group    => 'devops',
    require  => [ User['devops'], ],
  } -> 
  file { '/etc/mars/search-schema.json':
    replace => true,
    source  => '/opt/mars/marssite/dal/fixtures/search-schema.json' ,
  } 

  
}
