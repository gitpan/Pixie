CREATE TABLE px_object (
  px_oid varchar(255) NOT NULL default '',
  px_flat_obj blob NOT NULL,
  PRIMARY KEY  (px_oid)
);

CREATE TABLE px_lock_info ( 
  px_oid varchar(255) NOT NULL,
  px_locker varchar(255) NOT NULL,
  PRIMARY KEY (px_oid)
);

CREATE TABLE px_rootset (
  px_oid varchar(255) NOT NULL,
  PRIMARY KEY (px_oid)
);
