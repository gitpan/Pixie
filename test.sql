CREATE TABLE object (
  oid varchar(255) NOT NULL default '',
  flat_obj blob NOT NULL,
  PRIMARY KEY  (oid)
);

CREATE TABLE lock_info ( 
  oid varchar(255) NOT NULL,
  locker varchar(255) NOT NULL,
  PRIMARY KEY (oid)
);
