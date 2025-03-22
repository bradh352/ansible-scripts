def map_format(param_list, format_string):
    """format format_sting using elements in param_list for use with the map() filter"""
    if isinstance(param_list, list):
        return format_string % tuple(param_list)
    return format_string % param_list

class FilterModule(object):
    """custom format filters."""

    def filters(self):
        """Return the filter list."""
        return {
            'map_format': map_format
        }
