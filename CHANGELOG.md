NCS Navigator Configuration gem history
=======================================

0.3.3
-----

- New optional Core attribute: conflict_email_recipients.  (#12)

- New optional Core attribute: machine_account_username.  (#14)

- Make sc_id optional.  (#16)

- Make sampling_units_file optional.  (#17)

- Make recruitment_type_id optional.  (#18)

- Make core uri optional.  (#19)

0.3.2
-----

- New optional Core attribute: machine_account_password.  (#11)

0.3.1
-----

- Make Areas and SSUs optional for the PSU in the sampling unit CSV
  file. (#7)

0.3.0
-----

- New optional study center attribute: short_name. (#10)

- New optional attribute for Staff Portal and Core: mail_from. (#8)

- New optional study center attribute: `exception_email_recipients`. (#9)

0.2.0
-----

- New mandatory study center attribute: `recruitment_type_id`.

- Be more flexible about whitespace when parsing sampling unit CSV.

0.1.0
-----

- Ruby 1.9 compatibility.

0.0.1
-----

- Initial version based on configuration elements from Staff Portal
  and MDES Warehouse.
