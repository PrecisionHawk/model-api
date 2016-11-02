# model-api gem - api_metadata options reference

## Annotated Example

## Basic Options
* `alias` - Attribute name to use when exposing the field via the API
* `hide_when_nil` - Set `true` to hide the attribute in the payload when the value is `nil`.
  Otherwise set `false`.
* `id` - Indicates the field can be used to uniquely identify the resource.  Does not support using
  groups of attributes to uniquely identify resources, though this can be accomplished via
  `id_attributes` option on `model_metadata`.

## Field Formatting
### `parse`
  A method name or lambda to use when interpreting the attribute in API input.  For example,
  specifying `parse: :to_i` or, alternatively, `parse: ->(v) { v.to_i }`, will cast the attribute
  value as an integer whenever it's encountered as API input. 
### `render`
  A method name or lambda to use when rendering the attribute in API output.  For example,
  specifying `render: :to_i` or, alternatively, `render: ->(v) { v.to_i }`, will render the
  attribute as an integer in all API output.


## Filtering and Sorting
* `filter` - Allow users to filter by the attribute on endpoints that return collections.
* `sort` - Allow users to filter by the attribute on endpoints that return collections.

##### Usage Example
``` ruby
open_api
```

 

