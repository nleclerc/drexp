
mysql = require 'mysql2'
_ = require 'lodash'
php = require 'phpjs'
Promise = require 'bluebird'
fs = require 'fs'

startTime = new Date().getTime()

conf = require './config/local.json'
TARGET_FILE = 'result.json'
DEBUG = conf.debug

console.log "Connecting to #{conf.db.database}@#{conf.db.host}:#{conf.db.port}"

connection = mysql.createConnection conf.db

executeQuery = (query, parms...)->
	new Promise (resolve, reject)->
		connection.execute query, parms, (err, rows)->
			if err
				reject err
			else
				resolve rows

executeQuerySingle = (query, parms...)->
	executeQuery(query, parms...).then (rows)->
		if _.isEmpty rows
			null
		else
			rows[0]

getFieldValue = (nodeId, toto)->

processError = (err)->
	console.error 'Error during query:',err
	process.exit 1

parseFieldRows = (rows, columnName, isMultiple)->
	if isMultiple
		_.chain(rows).pluck(columnName).filter((value)-> value?).value()
	else
		rows[0][columnName]

fetchFilePaths = (fids)->
	promises = for fid in fids
		executeQuerySingle('SELECT * FROM files WHERE fid = ?',fid).then (row)->
			row?.filepath

	Promise.all promises

fetchContentField = (nid, contentData, fieldName, fields, fieldInstances)->


fetchContent = (nid, contentData, fieldNames, fields, fieldInstances)->
	promises = []

	for fieldName in fieldNames
		do (fieldName)->
			if DEBUG then console.log '>>>>>>>>>>>>>>>>',fieldName,fields[fieldName]

			fieldType = fields[fieldName].type

			columnName = switch fieldType
				when 'text'
					"#{fieldName}_value"

				when 'filefield'
					"#{fieldName}_fid"

				when 'nodereference'
					"#{fieldName}_nid"

			if not columnName?
				if DEBUG then console.log 'Unsupported field type:',fieldName,fieldType
			else
				if contentData.hasOwnProperty columnName
					if DEBUG then console.log '--------------',fieldName
					promises.push new Promise (resolve)->
						resolve
							name: fieldInstances[fieldName].label
							value: contentData[columnName]
				else
					promises.push executeQuery("SELECT * FROM content_#{fieldName} WHERE nid = ?", nid).then (rows)->
						if DEBUG then console.log '>>>>>>>>>>>>>>>>',fieldName,rows
						switch fieldType
							when 'text', 'nodereference'
								name: fieldInstances[fieldName].label
								value: parseFieldRows rows,columnName,fields[fieldName].multiple

							when 'filefield'
								fetchFilePaths(_.pluck(rows,"#{fieldName}_fid")).then (paths)->
									name: fieldInstances[fieldName].label
									value: paths

	Promise.all(promises).then (results)->
		if DEBUG then console.log 'Processing result for nid:',nid,results
		data = {}
		for result in results
			if DEBUG then console.log '>>>>>>>>',result
			data[result.name] = result.value if result?

		data

globalResult = {}

executeQuery('SELECT * FROM content_node_field').then((rows)->
	console.log "Found #{rows.length} field definitions."

	fields = {}

	for row in rows
		fields[row.field_name] = row
		row.global_settings = php.unserialize row.global_settings
		row.db_columns = php.unserialize row.db_columns

	executeQuery('SELECT * FROM node_type').then((rows)->

		types = {}

		for row in rows
			types[row.type] = row

		typePromise = Promise.resolve()

		for type in conf.types
			do (type)->
				typePromise = typePromise.then ->
					new Promise (resolve, reject)->
						if not types[type]
							reject "Type not found: #{type}"

						console.log 'Processing type:',type

						foundInstances = []
						globalResult[type] = foundInstances

						executeQuery('SELECT * FROM content_node_field_instance WHERE type_name = ?',type).then (rows)->
							fieldInstances = {}

							for row in rows
								fieldInstances[row.field_name] = row

							fieldNames = _.keys(fieldInstances)

							console.log "Found #{fieldNames.length} field instances for type #{type}."

							for name, instanceDef of fieldInstances
								def = fields[name]
								if DEBUG then console.log 'Processing field:',name, def.type
								if DEBUG then console.log 'Columns:',_.keys def.db_columns

							executeQuery('SELECT * FROM node WHERE type = ?',type).then (rows)->
								console.log "Found #{rows.length} instances of #{type}."

								promise = Promise.resolve()

								for row in rows
									do (row)->
										promise = promise.then ->
											nodeData =
												id: row.nid # rename nid to just id
											_.defaults nodeData, _.pick(row,'language','title','created','changed','tnid')

											executeQuerySingle("SELECT * FROM content_type_#{type} WHERE nid = ?",row.nid).then (contentData)->
												if not row?
													throw new Error "No content found for #{type}\##{row.nid}"

												if DEBUG then console.log 'Processing node:',row.nid,row,contentData

												fetchContent(row.nid, contentData, fieldNames, fields, fieldInstances).then (data)->
													_.defaults nodeData, data
													if DEBUG then console.log 'Found data:',nodeData

													foundInstances.push nodeData

								promise.then resolve

		typePromise.then ->
			console.log 'Writing result to file:',TARGET_FILE
			fs.writeFileSync TARGET_FILE, JSON.stringify(globalResult,null,4)
			console.log "Done in #{(new Date().getTime() - startTime)/1000.0}s."
			process.exit 0

	).catch processError
).catch processError
