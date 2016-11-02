# model-api gem - api_metadata options reference

## Annotated Example


## Rendering

#### `alias` - Change attribute name in API input and output
Default: `nil`.  Attribute name to use when exposing the field in API output, and when parsing the
field in .

#### `render` - Control attribute rendering in API output
A method name or lambda to use when rendering the attribute in API output.  For example,
specifying `render: :to_i` or, alternatively, `render: ->(v) { v.to_i }`, will render the
attribute as an integer in all API output.

#### `hide_when_nil` - Hide attribute in API output when `nil`
Default: `false`.  Set `true` to hide the attribute in API output whenever a value of `nil` is
encountered.  Set `false` to render the attribute in these cases.


## Parsing

#### `parse` - Control how attribute is parsed in API input
A method name or lambda to use when interpreting the attribute in API input.  For example,
specifying `parse: :to_i` or, alternatively, `parse: ->(v) { v.to_i }`, will cast the attribute
value as an integer whenever it's encountered as API input.


## Filtering and Sorting

#### `filter` - Allow collections to be filtered by the attribute 
Default: `false`.  Allow users to filter by the attribute on endpoints that return collections.

#### `sort` - Allow collections to be sorted by the attribute
Allow users to filter by the attribute on endpoints that return collections.


## Other Options

#### `id` - Use attribute to uniquely identify resource
Default: `false`.  Indicates the attribute is one that may be used to uniquely identify the
resource.  Though it is not possible to specify combinations of attributes that uniquely identify a
resource, this can be accomplished via the `id_attributes` option on `model_metadata`.

This information is primarily used to associate objects when creating or updating resources.  For
example, if the `email` field of a user is flagged as an `id` field, the email might be used to
reference the user (e.g. `"user": { "email": "user@domain.com" }`) when an administrator submits an
order on their behalf.
