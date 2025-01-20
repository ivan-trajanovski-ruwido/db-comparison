./getTypeList.pl "key=5d22af224da8&type_id=1"

./getBrandList.pl "key=5d22af224da8&type_name=AMP&age=3"
./getBrandList.pl "key=5d22af224da8&type_name=VCR&age=3"

./getModelList.pl "key=5d22af224da8&type_name=VCR&age=3&brand_name=son"

./cleanSignalList.pl "key=5d22af224da8&output=base64_blob"

./getSignalList.pl "key=5d22af224da8&type_name=TV&brand_name=samsung&model_name=un4&age=5&fkt=[[BASIC]]"

SELECT * FROM crossref JOIN crossref_to_global_code ON crossref.id = crossref_id JOIN global_code ON global_code.id = global_code_id WHERE
	brand_id IN (SELECT id FROM brand WHERE name_search REGEXP 'samsung')
    AND name_search REGEXP '^UN4'
    AND crossref.date >= DATE_SUB(CURDATE(), INTERVAL 5 YEAR) 
    AND function_id IN (1,27,28,32) 
    AND crossref_to_global_code.type_id = 1
    ORDER BY crossref.id;

SELECT global_code.*, COUNT(*) AS num, MAX(date) AS date  FROM crossref JOIN crossref_to_global_code ON crossref.id = crossref_id JOIN global_code ON global_code.id = global_code_id WHERE
	brand_id IN (SELECT id FROM brand WHERE name_search REGEXP 'samsung')
    AND crossref.source <> 'model_series'
    AND name_search REGEXP '^UN4'
    AND crossref.date >= DATE_SUB(CURDATE(), INTERVAL 5 YEAR) 
    AND function_id IN (1,27,28,32) 
    AND crossref_to_global_code.type_id = 1
    GROUP BY global_code.id, global_code.function_id
    ORDER BY num DESC, date DESC;

====
SELECT global_code.*, COUNT(*) AS num, MAX(date) AS date  FROM crossref JOIN crossref_to_global_code ON crossref.id = crossref_id JOIN global_code ON global_code.id = global_code_id WHERE
#	crossref.source <> ?
	AND crossref.name_search REGEXP ?
#	AND crossref.type_set & ?
	AND crossref.date >= DATE_SUB(CURDATE(), INTERVAL ? YEAR)
	AND crossref.brand_id IN (SELECT id FROM brand WHERE name_search REGEXP ?)
	AND global_code.function_id IN (?) GROUP BY global_code.id, global_code.function_id ORDER BY num DESC, date DESC===================== 1,27,28,32


NOTE:

	setEDID:
		store edid information, use fingerprint, etc

=====

CREATE TABLE `usage` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `client_key` varchar(12) DEFAULT NULL,
  `edid` varchar(2048) DEFAULT NULL,
  `nr_successful` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;


#edid           base64 encoded
#nr_sucessful
#       0       not used
#       -1      failed
#       1..n    sucessful response number
