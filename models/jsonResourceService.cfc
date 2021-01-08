/**
 * JSON based resource manager
 */

component accessors="true" extends="cbi18n.models.ResourceService" singleton {

    property name="interceptorService" inject="coldbox:interceptorService";

    /**
     * @controller.inject coldbox
     * @i18n.inject i18n@cbi18n
     * @settings.inject coldbox:moduleSettings:json-resource-service
     */

    function init(controller,i18n,settings){
        super.init(arguments.controller,arguments.i18n)
        variables.controller=arguments.controller;
        variables.i18n=arguments.i18n;
        variables.settings = arguments.settings;
        variables.aBundles = {};
    }

    /**
	 * Get a resource from a specific loaded bundle and locale
	 *
	 * @resource The resource (key) to retrieve from the main loaded bundle.
	 * @defaultValue A default value to send back if the resource (key) not found
	 * @locale Pass in which locale to take the resource from. By default it uses the user's current set locale
	 * @values An array, struct or simple string of value replacements to use on the resource string
	 * @bundle The bundle alias to use to get the resource from when using multiple resource bundles. By default the bundle name used is 'default'
	 */
	function getResource(
		required resource,
		defaultValue,
		locale = variables.i18n.getfwLocale(),
		values,
		bundle = "default"
	){
		var thisBundle = {};
		var thisLocale = arguments.locale;
		var rbFile     = "";

		// check for resource@bundle convention:
		if ( find( "@", arguments.resource ) ) {
			arguments.bundle   = listLast( arguments.resource, "@" );
			arguments.resource = listFirst( arguments.resource, "@" );
        }
//		try {
			// Check if the locale has a language bundle loaded in memory
			if (
				!structKeyExists( variables.aBundles, arguments.bundle ) ||
				(
					structKeyExists( variables.aBundles, arguments.bundle ) && !structKeyExists(
						variables.aBundles[ arguments.bundle ],
						arguments.locale
					)
				)
			) {

				// Try to load the language bundle either by default or config search
				if ( arguments.bundle eq "default" ) {
                    rbFile = variables.settings.defaultResourceBundle.filename;
                    rbRoot = variables.settings.defaultResourceBundle.resourceRoot;
				} else if (
					structKeyExists(
						variables.settings.resourceBundles,
						arguments.bundle
					)
				) {
                    rbFile = variables.settings.resourceBundles[ arguments.bundle ].filename;
                    rbRoot = variables.settings.resourceBundles[ arguments.bundle ].resourceRoot;
				}
				loadBundle(
                    rbFile  = rbFile,
                    rbRoot  = rbRoot,
                    rbAlias = arguments.bundle,
					rbLocale = arguments.locale
                );

			}

            // Get the language reference now
			thisBundle = variables.aBundles[ arguments.bundle ][ arguments.locale ];
//		} catch ( Any e ) {
//			throw(
//				message = "Error getting language (#arguments.locale#) bundle for resource (#arguments.resource#). Exception Message #e.message#",
//				detail  = e.detail & e.tagContext.toString(),
//				type    = "ResourceBundle.BundleLoadingException"
//			);
//		}

		// Check if resource does NOT exists?
		if ( !structKeyExists( thisBundle, arguments.resource ) ) {
			variables.interceptorService.processState(
				"onJsonUnknownTranslation",
				{
					resource : arguments.resource,
					locale   : arguments.locale,
					bundle   : arguments.bundle
				}
			);

			// if logging enable
			if ( variables.settings.logUnknownTranslation ) {
				log.error( variables.settings.unknownTranslation & " key: #arguments.resource#" );
			}

			// argument defaultValue was 'default'. both NOT required in function definition so we can check both
			// first check the new 'defaultValue' param
			if ( structKeyExists( arguments, "defaultValue" ) ) {
				return arguments.defaultValue;
			}
			// if still using the old argument, return this. You will never arrive here when using 'defaultValue'
			if ( structKeyExists( arguments, "default" ) ) {
				return arguments.default;
			}

			// Check unknown translation setting
			if ( len( variables.settings.unknownTranslation ) ) {
				return variables.settings.unknownTranslation & " key: #arguments.resource#";
			}

			// Else return nasty unknown string.
			return "_UNKNOWNTRANSLATION_FOR_#arguments.resource#_";
		}

		// Return Resource with value replacements
		if ( structKeyExists( arguments, "values" ) ) {
			return formatRBString(
				thisBundle[ arguments.resource ],
				arguments.values
			);
		}

		// return from bundle
		return thisBundle[ arguments.resource ];
	}

    	/**
	 * Tries to load a resource bundle into ColdBox memory if not loaded already
	 *
	 * @rbFile This must be the path + filename UP to but NOT including the locale. We auto-add .properties or .json to the end alongside the locale
	 * @rbLocale The locale of the bundle to load
	 * @force Forces the loading of the bundle even if its in memory
	 * @rbAlias The unique alias name used to store this resource bundle in memory. The default name is the name of the rbFile passed if not passed.
	 */
	any function loadBundle(
        required string rBFile,
        required string rbRoot,
		string rbLocale = "en_US",
		string rbAlias  = "default"
	){
        // Verify bundle register name exists
		if (
			!structKeyExists(
				variables.aBundles,
				arguments.rbAlias
			)
		) {
			lock
				name          ="rbregister.#hash( arguments.rbFile & arguments.rbAlias )#"
				type          ="exclusive"
				timeout       ="10"
				throwontimeout="true" {
				if (
					!structKeyExists(
						variables.aBundles,
						arguments.rbAlias
					)
				) {
                    variables.aBundles[ arguments.rbAlias ] = {};
				}
			}
		}
		// Verify bundle register locale exists or forced
		if (
			!structKeyExists(
				variables.aBundles[ arguments.rbAlias ],
				arguments.rbLocale
			) 
		) {
			lock
				name          ="rbload.#hash( arguments.rbFile & arguments.rbLocale )#"
				type          ="exclusive"
				timeout       ="10"
				throwontimeout="true" {
				if (
					!structKeyExists(
						variables.aBundles[ arguments.rbAlias ],
						arguments.rbLocale
					) || arguments.force
				) {
					// load a bundle and store it.
					variables.aBundles[ arguments.rbAlias ][ arguments.rbLocale ] = getResourceBundle(
                        rbFile   = arguments.rbFile,
                        rbRoot  = arguments.rbRoot,
						rbLocale = arguments.rbLocale
					);
					// logging
					if ( log.canInfo() ) {
						log.info(
							"Loaded bundle: #arguments.rbFile#:#arguments.rbAlias# for locale: #arguments.rbLocale#"
						);
					}
				}
			}
		}
		return this;
	}

	/************************************************************************************/
	/****************************** UTILITY METHODS *************************************/
	/************************************************************************************/

	/**
	 * Reads,parses and returns a resource bundle in struct format
	 *
	 * @rbFile This must be filename PLUS .json extension
     * @rbRoot Path to the language resource root map
	 * @rbLocale The locale of the resource bundle
	 *
	 * @throws ResourceBundle.InvalidBundlePath if bundlePath is not found
	 */
	struct function getResourceBundle( 
        required rbFile, 
        required rbRoot,
        rbLocale = "en_US" 
    ){
        //make sure rbRoot has trailing slash
        if ( ! arguments.rbRoot.right(1) =="/" ){
            arguments.rbRoot=arguments.rbRoot&"/";
        }

        // try to load hierarchical resources from default to LANG_COUNTRY_VARIANT
        // #rbroot#/default/#rbfile#
        // #rbroot#/LANG/#rbfile#
        // #rbroot#/LANG_COUNTRY/#rbfile#
        // #rbroot#/rbFile_LANG_COUNTRY_VARIANT/#rbfile#
		// All items in resourceBundle will be overwritten by more specific ones.
        // Create all file options from locale
        
        // add base resource, without language, country or variant
        var smartBundleFiles = [ "#rbroot#default/#rbfile#" ];
		// include lang, country and variant (if present)
        // extract and add to bundleArray by splitting rbLocale as list on '_'
        var languageDir = "";
		arguments.rbLocale.listEach( ( localePart, index, list )=>{
            languageDir = listAppend(languageDir, localePart,"_");
			smartBundleFiles.append( "#rbroot##languageDir#/#rbfile#"  );
        }, "_" );
        
		// load all resource files for all lang, country and variants
		// and overwrite parent keys when present so you you will always have defaults
		// AND specific resource values for countries and variants without duplicating everything.
		var resourceBundle      = structNew();
		var isValidBundleLoaded = false;
		smartBundleFiles.each( function( resourceFile ){
			var resourceBundleFullPath = variables.controller.locateFilePath( resourceFile );
			if ( resourceBundleFullPath.len() ) {
				resourceBundle.append(
					_loadJsonSubBundle( resourceBundleFullPath ),
					true
				); // append and overwrite
				isValidBundleLoaded = true; // at least one bundle loaded so no errors
			};
		} );

		// Validate resource is loaded or error.
		if ( !isValidBundleLoaded ) {
            var rbDefaultBundleFile = smartBundleFiles.first();
            var rbLanguageBundleFile = smartBundleFiles.last();
            var rbFilePath = "#arguments.rbroot#/#arguments.rbLocale#/#arguments.rbfile#";
			var rbFullPath = variables.controller.locateFilePath( rbFilePath );
			throw(
				message = "The resource bundle file: #rbLanguageBundleFile# does not exist. Default bundel file #rbDefaultBundleFile# does not exist. Please check your path",
				type    = "ResourceBundle.InvalidBundlePath",
				detail  = "FullPath: #rbFullPath#"
			);
		}
		return resourceBundle;
	}
	/**
	 * loads a JSON resource file from file
	 *
	 * @resourceBundleFullPath full path to a (partial) resourceFile
	 *
	 * @return struct resourcebundle
	 * @throws ResourceBundle.InvalidJSONBundlePath
	 */
	private function _loadJsonSubBundle( required string resourceBundleFullPath ){
		try {
			return _flattenStruct( deserializeJSON( fileRead( arguments.resourceBundleFullPath ) ) );
		} catch ( any e ) {
			throw(
				message = "Invalid JSON resource bundle #arguments.resourceBundleFullPath#",
				type    = "ResourceBundle.InvalidJSONBundlePath"
			)
		}
	}

	/**
	 * flatten a struct, so we can use keys in format 'main.sub1.sub2.resource'.
	 *
	 * @originalStruct
	 * @flattenedStruct necessary for recursion
	 * @prefix_string necessary for processing, so key kan be prepended with parent name
	 *
	 *
	 * @return struct resourcebundle
	 * @throws ResourceBundle.InvalidBundlePath
	 */
	private function _flattenStruct(
		required struct originalStruct,
		struct flattenedStruct = {},
		string prefixString    = ""
	){
		arguments.originalStruct.each( function( key, value ){
			if ( isStruct( value ) ) {
				flattenedStruct = _flattenStruct(
					value,
					flattenedStruct,
					"#prefixString##key#."
				);
			} else {
				structInsert(
					flattenedStruct,
					"#prefixString##key#",
					value,
					false
				);
			}
		} );
		return flattenedStruct;
	}



}
