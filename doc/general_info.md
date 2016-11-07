# model-api gem - General Usage information

### Inheritance
The `model-api` gem allows attributes defined in a base class to be ammended or overridden in
subclasses.

Suppose that, for example, if you define an `order_id` `alias` for an attribute in your `Order`
class, and an `online_order_id` `alias` in your `OnlineOrder` subclass.  The attribute will appear
as `order_id` for all `Order` instances and `online_order_id` for all `OnlineOrder` instances.

Likewise, in the event no `alias` is specified in the Order base class and an `alias` of
`online_order_id` is specified in the `OnlineOrder` subclass, the attribute appears with its
unmodified name for `Order` instances and as `online_order_id` for `OnlineOrder` instances.

### Common Callback Options
Common callback options (generally passed via the `opts` `Hash` parameter as the final callback
argument) will include the following standard options:

* `:action` - Name of the invoked API endpoint
* `:admin` - Indicates whether administrative content is to be rendered
* `:admin_user` - Indicates whether user has admin privileges *(doesn't always match `:admin`)*
* `:api_context` - API query context object, used to query resources with all of the appropriate
    scoping rules applied.  (Example: Order queries might be limited to those orders the current
    user was responsible for creating unless that user is an administrator.)
* `:model_class` - If configured, the ActiveRecord model class associated with the API endpoint
* `:user` - The currently-logged-in user
* `:user_id` - ID of the currently-logged-in user

*Note API-specific additional options may be universally included by overriding the
`prepare_options()` method in the API controller.*

### API Operation Categories
Below is a summary of API operation categories used when controlling when and how attributes appear:

* `:index` - View list of resources
* `:show` - View individual resource
* `:create` - Create a new resource
* `:update`, `:patch` - Update an existing resource *(note `model-api` processes `:update` as a
    `:patch`)*
* `:destroy` - Destroy a resource
* `:other` - Operation that does not fit into one of the aformeneted CRUD operation categories
* `:filter` - Used when attribute is being evaluated for filtering purposes
* `:sort` - Used when attribute is being evaluated for sorted purposes
