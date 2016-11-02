# model-api gem - api_metadata options reference

## Annotated Example


## Rendering

#### [`alias` - Change attribute name in API input and output](#alias)
Default: `nil`.  Attribute name to use when exposing the field in API output, and when parsing the
field in .

#### [`render` - Control attribute rendering in API output](#render)
A method name or lambda to use when rendering the attribute in API output.  For example,
specifying `render: :to_i` or, alternatively, `render: ->(v) { v.to_i }`, will render the
attribute as an integer in all API output.

#### [`hide_when_nil` - Hide attribute in API output when `nil`](#hide_when_nil)
Default: `false`.  Set `true` to hide the attribute in API output whenever a value of `nil` is
encountered.  Set `false` to render the attribute in these cases.

#### [`attributes` - Controls what attributes appear for nested objects](#attributes)
Default: `nil`.  Specified either as an `Array` or as a `Hash`, this option controls which
attributes for a nested object (e.g. the user information rendered in order output) should appear
when rendering API output.

When specified as an `Array`, only attributes matching the attribute names specified will be
included when rendering the nested object.  When specified as a `Hash`, the behavior is identical
except that overriding attribute options can be specified for the attributes.  These options
override whatever options have been configured for the attribute in the `api_attributes` block on
the nested object's model class.

## Parsing

#### [`parse` - Control how attribute is parsed in API input](#parse)
A method name or lambda to use when interpreting the attribute in API input.  For example,
specifying `parse: :to_i` or, alternatively, `parse: ->(v) { v.to_i }`, will cast the attribute
value as an integer whenever it's encountered as API input.


## Filtering and Sorting

#### [`filter` - Allow collections to be filtered by the attribute](#filter) 
Default: `false`.  Allow users to filter by the attribute on endpoints that return collections.

#### [`sort` - Allow collections to be sorted by the attribute](#sort)
Allow users to filter by the attribute on endpoints that return collections.


## Access Control

#### [`admin_only` - Hide content except in administrator content](#sort)
When specified, the field will remain hidden except when the content is being rendendered as
administrator content.  This implies (a) the current user must be an administrator, and (b) the
administrator mode for the endpoint must have been enabled.

Note that there are two overridable methods in the controller (defined in
`ModelApi::BaseController`) that determine whether the current user is an administrator.  The
`admin_user?` method indicates if the current user is an administrator.  The `admin_content?`
method indicates if the content interpreted by and rendered from the API should be administrator
content.

## Other Options

#### [`id` - Use attribute to uniquely identify resource](#id)
Default: `false`.  Indicates the attribute is one that may be used to uniquely identify the
resource.  Though it is not possible to specify combinations of attributes that uniquely identify a
resource, this can be accomplished via the `id_attributes` option on `model_metadata`.

This information is primarily used to associate objects when creating or updating resources.  For
example, if the `email` field of a user is flagged as an `id` field, the email might be used to
reference the user (e.g. `"user": { "email": "user@domain.com" }`) when an administrator submits an
order on their behalf.
