module Rbsh

  # This class is used as the context (binding) when executing ruby code from the shell.
  class Context
    def get_binding
      binding
    end
  end
end
