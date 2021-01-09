
# Welcome to the cbi18n JSON resourceService module

This module will enhance the cbi18n module. The cbi18n module by Ortus Solutions offers i18n capabilities, java resource bundles and localization. 
The cbi18n JSON resourceService module replaces the default resource manager and has the following advantages
- json resource files instead of java resource files, so easier editing.
- language/locale resources organised by directory
- option for default resource file
- hierarchical resources, so e.g lang_COUNTRY_*variation* locale will compose your resources from generic to most specific by reading the following files (if present)

  - resources/lang/lang_COUNTRY_*variation*/myResource.json
  - resources/lang/lang_COUNTRY/myResource.json
  - resources/lang/lang/myResource.json
  - resources/lang/default/myResource.json

  This makes it possible to define a main language and create specific translations only for some words which are different in certain countries or even *regions*.
- interceptor **onJsonUnknownTranslation**, so you can define your own mechanism for handling missing translations

## License
----------
Apache License, Version 2.0.

## Links
- https://github.com/wpdebruin/cbi18n-json-resources
- https://www.forgebox.io/view/cbi18n-json-resources
- https://shiftinsert.nl

## Requirements
- Lucee 5+, Coldfusion 2016+
- Coldbox 5+
- cbi18n module

## Installation
Use coldbox to install
```javascript
box install cbi18n-json-resources
```
## Settings
When using `cbi18n-json-resources` you have to configure the cbi18n module first. This module does not have the modulesettings syntax (yet) as most modern modules do, so you have to configure a `i18n` block in your coldbox config file

```javascript
i18n = {
    localeStorage="cookie",
    customResourceService="cbi18n-json-resources.models.jsonResourceService",
    defaultLocale = "en_US"
}
```
i18n has more settings, but the above settings will be sufficient in almost all cases. Other settings for resource files will be done in the module settings for `cbi18n-json-resources`. For this module we use the modulesettings block in your coldbox config file
```javascript
modulesettings = {
    cbi18n-json-resources: {
        defaultResourceBundle = {
            "filename" = "default.json",
            "resourceRoot" = "resources/lang/"
        },       
        resourceBundles = {
            someAlias = {
                filename = "myAlias.json",
                resourceRoot = "resources/lang"
            },
            anotherAlias = {
                filename = "sometest.json",
                resourceRoot = "resources/lang"
            }
        },
        // by default unknownTranslations will be logged
        "logUnknownTranslation" = true,
        // 
        "unknownTranslation"    : ""        
    }
}
```
In the `cbi18n-json-resources` settings you can specify a default resourceBundle, and multiple resourceBundle aliases. Both are not required but you have to specify at least one bundle to use this module.

## Resource JSON format: flat or nested
You can specify your resources in two different formats, flat and Nested.
```javascript
//flat
"buttons.OK"        : "OK",
"buttons.Cancel"    : "Cancel",

// vs nested
"buttons" : {
    "OK"        : "OK",
    "Cancel"    : "Cancel"
}
```
The module will automatically detect if you are using `flat` or `nested` format.
## ResourceRoot and filename for bundles
As you can see, each bundle has two properties a `filename` and a `resourceRoot`. This is different from the standard `cbi18n` bundle. We organize languages and bundles per directory.
```javascript
defaultResourceBundle = {
    "filename" = "default.json",
    "resourceRoot" = "resources/lang/"
}    
```
So if you are using the following locales en_US and nl_NL you will have a `resources/lang` root directory. You have to create your json files in the following places.
- resources/lang/en_US/default.json
- resources/lang/nl_NL/default.json
You can use any filename you want, as long as you specify it in your defaultResourceBundle settings.

### Hierarchical settings
Sometimes you want to provide translations for two very related locales, e.g Dutch (nl_NL) or Flemish(nl_BE). With hierarchial locales you don't have to copy all Dutch translations to Flemish (or en_US to en_GB). You can just use ONE general locale, e.g nl (or en). In this case you only have to provide this file
- resources/lang/`nl`/default.json

wich wil be used by both nl_NL and nl_BE. If you want to provide different translations for one (or both) of these languages, you can create more specific resource files for each locale, e.g
- resources/lang/`nl`/default.json
- resources/lang/`nl_NL`/default.json
- resources/lang/`nl_BE`/default.json

### Default resource files
There might be situations where you ALWAYS want to provide a translation, even if it is not in the correct language. Simple example is a validation library which has en_US as a default language. So if I want to provide Dutch translations for my validations and fall back to English if there is no such translation, I could use the following resource files
- resources/lang/`default`/validation.json (my default english resource file with all en_US translations)
- resources/lang/`nl`/validation.json (dutch translations)
- resources/lang/`nl_BE`/validation.json (specific flemish translations, fallback to `nl` and `default`)
- resources/lang/`en_GB`/validation.json (specific british translations, fallback to `default`)

### Multiple resource files
You might want to keep your translated resources in multiple files, e.g. for different modules of specific functionality. In this case you can specify multiple resources bundle aliases, e.g.
```javascript
resourceBundles = {
    someAlias = {
        filename = "myAlias.json",
        resourceRoot = "resources/lang"
    },
    anotherAlias = {
        filename = "sometest.json",
        resourceRoot = "resources/lang"
    }
},
```
You can use these resources by specifying your aliases in the `getResource()` or `$r()` call (exactly the same as in the parent `cbi18n` module).
Multiple ways to specify your resources:
```javascript
// default resource in a handler or view
buttonOkText = getResource("button.OK")
buttonOkText = $r("button.OK")
// in a model
buttonOkText = injectedResourceService.getResource("button.OK")
// resource alias in a handler or view
buttonOkText = getResource("button.OK@someAlias") //convenient @syntax for alias
buttonCancelText = $r("button.Cancel@anotherAlias")
buttonOkText = getResource(resource="button.OK", bundle="someAlias") //convenient @syntax for alias
buttonCancelText = $r(resource="button.Cancel", bundle="anotherAlias")
```
## Interception point
This module announces a **onJsonUnknownTranslation** interception. The `(intercept)data` in your interceptor will show
- resource
- locale
- bundle

This interceptions point was created so you can create your own handling of missing translations, for example by sending them to an external logging service like sentry.
