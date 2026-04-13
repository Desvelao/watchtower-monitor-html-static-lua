# config.json

Available filters

## Inputs

### http

Example using a watchtower-server:
```json
{
    "inputs": [
        {
            "type": "http",
            "options": {
                "url": "http://WATCHTOWER_SERVER:8080/api/items?from={wrap_ctx.item_from}&size={options.custom_values.size}",
                "custom_values": {
                    "size": 10
                },
                "json": {
                    "items_path": "items",
                    "total_items_path": "total_items",
                    "item_map": {
                        "_id": "id",
                        "id": "name",
                        "url": "url"
                    }
                }
            }
        }
    ]
}
```

#### Options

| Name | Description | Type | Allowed values |
| --- | --- | --- | --- |
| `url` | Define the server URL where retrieve the items to monitor. | Required | string |
| `request_options` | Define the options to be used in the fetch request (GET). See lua-request library for more details. | Optional | table |
| `json.total_item_path` | Define the JSON path to the total items in the response. | Required | string |
| `json.items_path` | Define the JSON path to the items list in the response. | string | Required |
| `json.item_map` | Define a field map from the response to the process management. | Optional | table{string, string} |


URL interpolation:

| Variable | Description |
| --- | --- |
| `wrap_ctx.item_from` | Define the starting item to retrieve |
| `wrap_ctx.total_items` | Define the items count to retrieve. This is used internally |
| `options.*` | Define path to some value in the options. This allow to define some variables used in the URL using other options keys |


### csv

```json
{
    "file": "/data/items.csv",
    "columns": {
        "name": {
            "include": true
        },
        "url": {
            "include": true
        },
        "bool_val": "bool",
        "number_val": {
            "format": "number"
        }
    }
}
```

#### Options

| Name | Description | Type | Allowed values |
| --- | --- | --- | --- |
| `file` | Define the CSV file path | Required | string |
| `header` | Define if the CSV file has the header and the properties will be the header, else define columns | Optional | boolean |
| `columns` | Define the columns to include and format. | Optional | table{[key:string]: {include?: boolean, format[bool, number],} | string[bool, number]} |
| `rename` | Rename headers. | Optional | table{[header_field:string]: string}} |

NOTE: at least one of `header` or `columns` are required.


## Filters

### drop

Drop the process of an item

```json
{
    "filters": [
        {
            "if": "not item.price",
            "type": "drop"
        }
    ]
}
```

### normalize_json

Format the extracted values.
```json
{
    "type": "normalize_json",
    "options": {
        "fields": [
            {"field": "_id"},
            {"field": "id", "format": "string"},
            {"field": "url", "format": "string"},
            {"field": "price", "format": "number"},
            {"field": "discount"},
            {"field": "timestamp"},
            {"field": "available"}
        ]
    }
}
```

#### Options

| Name | Description | Type | Allowed values |
| --- | --- | --- | --- |
| `fields` | List of fields to normalize | Required | string, {field: string, format?: string, format_script?: string, default: any}[] | - |


#### Option: fields

The fields can be defined:
- string: `_id`, `name`, etc...
- table:

| Field | Description | Type |
| --- | --- | --- |
| `field` | Define the field path to select | Required |
| `format` | Apply a formatter to the value: `boolean`, `number` | Optional |
| `format_script` | Define a string to be evaluted. Interpolate: `value` (value), `ctx` (process data context), `env` (global Lua variables) | Optional |
| `default` | Define the default value the field path does not exist | Optional |

Examples:

```lua
{"field": "_id"}
{"field": "name"}
{"field": "price", format: "number"}
{"field": "has_price_string", format_script: "if value then return 'has_value' else return 'has_no_value end'"}
{"field": "unknown_field", "default": false}
```

The field path can select nested values using the dot notation, e.g. `a.b.c`.

### web_scraper

Example:

```json
{
    "type": "web_scraper",
    "options": {
        "sites": [
            {
                "url": "http://watchtower_server:8080/api/scrapers/remote_config_lua/site"
            },
            {
                "name": "store1",
                "fields": {
                    "available": {
                        "selector": [
                            ".current-price-value"
                        ],
                        "validate": "",
                        "transform": "to_boolean"
                    },
                    "discount": {
                        "selector": [
                            ".product-discount .regular-price"
                        ],
                        "validate": "",
                        "transform": "match(\"(%d+,?%.?%d*)\") | replace(\",\",\".\") | to_number"
                    },
                    "price": {
                        "selector": [
                            ".current-price-value"
                        ],
                        "validate": "",
                        "transform": "match(\"(%d+,?%.?%d*)\") | replace(\",\",\".\") | to_number"
                    }
                },
                "urls_match": [
                    "https://www%.store1"
                ],
            },
            {
                "name": "store2",
                "fields": {
                    "available": {
                        "selector": [
                            "span.a-price > span.a-offscreen"
                        ],
                        "validate": "",
                        "transform": "to_boolean"
                    },
                    "discount": {
                        "selector": [
                            "span.savingPriceOverride"
                        ],
                        "validate": "",
                        "transform": ""
                    },
                    "price": {
                        "selector": [
                            "span.a-price > span.a-offscreen"
                        ],
                        "validate": "",
                        "transform": "replace(\",\",\".\") | match(\"(%d+%.?%d*)\") | to_number"
                    }
                },
                "urls_match": [
                    "https://store2%.com",
                    "https://www%.store2%.com"
                ]
            }
        ]
    }
}
```

#### Options

| Name | Description | Type | Allowed values |
| --- | --- | --- | --- |
| `sites` | Define a list of API to retrieve the sites | Required | Array of {url: string} | {name: string, fields: {[key: available, discount, price]: {selector: string, validate: string, transform?: string}}} | - |

## Outputs

### alert-server

### file-ndjson

Export the data to a file as ndJSON (each line is a JSON).

Example:

```json
{
    "type": "file-ndjson",
    "options": {
        "file": "/data/monitoring.json",
        "fields": ["timestamp", "id", "price", "available", "discount", "url"],
        "order": ["timestamp", "id", "price", "available", "discount", "url"]
    }
}
```

#### Options

| Name | Description | Type | Allowd values |
| --- | --- | --- | --- |
| `file` | Define the path to the file. | Required | string |
| `fields` | Define the fields to be included in the JSON. | Optional | string[] |
| `order` | Define the order of fields in the JSON. | Optional | string[] |

### stdout

Send to stdout. It allows to interpolate the process context data.

Example:

```json
{
    "type": "stdout",
    "options": {
        "template": "**Product**: {data._id}, **Price**: {data.price}, **discount**: {data.discount}, **url**: {data.url}, **available**: {data.available}"
    }
}
```

#### Options

| Name | Description | Type | Allowed values |
| --- | --- | --- | --- |
| `template` | Define the template string. Use `{}` to interpolate variables. | Required | string |

#### Option: template

Variables:
- `data`: process context

### webhook

Send a request to a webhook.

#### Options

| Name | Description | Type | Allowd values |
| --- | --- | --- | --- |
| `method` | HTTP method | Optional: `post` | `get`, `put`, `post`, `delete`, `head` |
| `url` | URL to send the data | Required | string |
| `headers` | Request headers | Optional | table |
| `payload_script` | Template that defines the payload | Required | string |
| `payload_encoding` | Define the encoding | Optional | `json`, `nil` |
