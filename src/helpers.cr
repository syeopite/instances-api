module InstancesApi::Helpers
  macro create_mutex_storage(storage_name, key, value)
    class {{storage_name.id}}
      @mutex : Mutex = Mutex.new()
      @{{key.id}} = {{value}}

      def get(&)
        @mutex.lock
        begin
          yield @{{key.id}}
        ensure
          @mutex.unlock
        end
      end
    end
  end
end
