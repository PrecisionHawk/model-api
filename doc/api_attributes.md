# model-api gem - api_metadata options reference

## Annotated Example


## Rendering

#### `alias`
*Change the attribute name as it appears in API input and output.*  Default: `nil` (use attribute
name).  An alternate attribute name to use when exposing the field in API output, and when parsing
the field within API input.

#### `render`
*Control attribute rendering in API output.*  A method name or lambda to use when rendering the
attribute in API output.  For example, specifying `render: :to_i` or, alternatively,
`render: ->(v) { v.to_i }`, will render the attribute as an integer in all API output.

#### `hide_when_nil`
*Hide attribute in API output when `nil`.*  Default: `false`.  Set `true` to hide the attribute in
API output whenever a value of `nil` is encountered.  Set `false` to render the attribute in these
cases.

#### `attributes`
*Control what attributes appear for nested objects.*  Default: `nil` (use nested object's metadata
as-is). Specified either as an `Array` or as a `Hash`, this option controls which attributes for a
nested object (e.g. the user information rendered in order output) should appear when rendering API
output.

When specified as an `Array`, only attributes matching the attribute names specified will be
included when rendering the nested object.  When specified as a `Hash`, the behavior is identical
except that overriding attribute options can be specified for the attributes.  These options
override whatever options have been configured for the attribute in the `api_attributes` block on
the nested object's model class.

## Parsing

#### `parse`
*Controls how attribute is parsed in API input.*  The value provided can either be a method name or
callback (lambda / proc) to use when interpreting the attribute in API input.  For example,
specifying `parse: :to_i` or `parse: ->(v) { v.to_i }` will cast the attribute value as an integer
whenever it's encountered as API input.

When specified as a callback, the following arguments are optionally provided:
 * `obj` - Value to be parsed
 * `opts` - Options collection (See
     [Common Callback Options](general_info.md#common-callback-options) for details)


## Filtering and Sorting

#### `filter`
*Allow collections to be filtered by the attribute.*  Default: `false`.  Allow users to filter by
the attribute on endpoints that return collections.

Value can be specified as a boolean or as a callback lambda or proc.  When specified as a callback,
the following argument is optionally provided:
 * `opts` - Options collection (See
     [Common Callback Options](general_info.md#common-callback-options) for details)

#### `sort`
*Allow collections to be sorted by the attribute.*  Default: `false`.  Allow users to filter by the
attribute on endpoints that return collections.

Value can be specified as a boolean or as a callback lambda or proc.  When specified as a callback,
the following argument is optionally provided:
 * `opts` - Options collection (See
     [Common Callback Options](general_info.md#common-callback-options) for details)


## Hiding / Access Control


#### `only`
*Specify the only scenarios when attribute should appear.  Default `null`.  Can be
specified either as an array of [API Operation Category](general_info.md#api-operation-categories)
values or as a callback lambda or proc.

When specified as a callback, the following arguments are optionally provided:
 * `obj` - ActiveRecord object whose visibility is to be controlled
 * `operation` - [API Operation Category](general_info.md#api-operation-categories) associated with
     the endpoint (provided as `Symbol`)
 * `opts` - Options collection (See
     [Common Callback Options](general_info.md#common-callback-options) for details)

#### `only_actions`
*Specify the only scenarios when attribute should appear.  Default `null`.  Can be
specified either as an array of endpoint names or as a callback lambda or proc.

When specified as a callback, the following arguments are optionally provided:
 * `obj` - ActiveRecord object whose visibility is to be controlled
 * `action` - The name of the endpoint that was invoked (provided as `Symbol`)
 * `opts` - Options collection (See
     [Common Callback Options](general_info.md#common-callback-options) for details)

#### `except`
*Specify scenarios when attribute should be hidden.  Default `null`.  Can be specified either as an
array of [API Operation Category](general_info.md#api-operation-categories) values or as a callback
lambda or proc.

When specified as a callback, the following arguments are optionally provided:
 * `obj` - ActiveRecord object whose visibility is to be controlled
 * `operation` - [API Operation Category](general_info.md#api-operation-categories) associated with
     the endpoint (provided as `Symbol`)
 * `opts` - Options collection (See
     [Common Callback Options](general_info.md#common-callback-options) for details)

#### `read_only`
*Specify attribute should be readable but not writable via the API.  Default `null`.  Can be
specified either as an array of [API Operation Category](general_info.md#api-operation-categories)
values or as a callback lambda or proc.

When specified as a callback, the following arguments are optionally provided:
 * `obj` - ActiveRecord object whose visibility is to be controlled
 * `operation` - [API Operation Category](general_info.md#api-operation-categories) associated with
     the endpoint (provided as `Symbol`)
 * `opts` - Options collection (See
     [Common Callback Options](general_info.md#common-callback-options) for details)

#### `write_only`
*Specify attribute should be writable but not readable via the API.  Default `null`.  Can be
specified either as an array of [API Operation Category](general_info.md#api-operation-categories)
values or as a callback lambda or proc.

When specified as a callback, the following arguments are optionally provided:
 * `obj` - ActiveRecord object whose visibility is to be controlled
 * `operation` - [API Operation Category](general_info.md#api-operation-categories) associated with
     the endpoint (provided as `Symbol`)
 * `opts` - Options collection (See
     [Common Callback Options](general_info.md#common-callback-options) for details)

#### `admin_only`
*Hide attribute except when in administrator content mode.*  When specified, the field will remain
hidden except when the content is being rendendered as administrator content.  This implies
(a) the current user must be an administrator, and (b) the administrator mode for the endpoint must
have been enabled.

Note that there are two overridable methods in the controller (defined in
`ModelApi::BaseController`) that determine whether the current user is an administrator.  The
`admin_user?` method indicates if the current user is an administrator.  The `admin_content?`
method indicates if the content interpreted by and rendered from the API should be administrator
content.

## Other Options

#### `id`
*Use attribute to uniquely identify the resource to which it belongs.*  Default: `false`.  Indicates
the attribute is one that may be used to uniquely identify the resource.  Though it is not possible
to specify combinations of attributes that uniquely identify a resource, this can be accomplished
via the `id_attributes` option on `model_metadata`.

This information is primarily used to associate objects when creating or updating resources.  For
example, if the `email` field of a user is flagged as an `id` field, the email might be used to
reference the user (e.g. `"user": { "email": "user@domain.com" }`) when an administrator submits an
order on their behalf.

#### `on_exception`
Default: `null`.  Indicate how to handle an exception that occurs when attempting to assign a value
to the attribute.  Can be specified as a `Hash` of exception-class-to-handler mappings, or as a
handler that is to be applied regardless of the exception class.  Each handler can either be
specified as a `String` or as a callback lambda or proc.

If provided as a `String`, an error message consisting of the value and appended `String` is
rendered in the error messages produced by the API response.
 
When supplied as a callback lambda, the following arguments are supplied to the callback:
 * `obj` - ActiveRecord object on which the attribute value was to be assigned
 * `e` - Exception produced as a result of attempting the attribute assignment
 * `opts` - Options collection (See
     [Common Callback Options](general_info.md#common-callback-options) for details)
