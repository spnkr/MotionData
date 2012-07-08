module MotionData
  class Context < NSManagedObjectContext
    class << self
      attr_accessor :root, :main

      # This returns the default context for the current thread. On the main
      # thread this will be `Context.main` and on other threads this will lazy
      # load (and cache) a context through `Context.context`
      def default
        Thread.current[:motionDataDefaultContext] || (main if NSThread.mainThread?)
      end

      def withDefault(context)
        Thread.current[:motionDataDefaultContext] = context
        yield
      ensure
        Thread.current[:motionDataDefaultContext] = nil
      end

      # This is the root context for all contexts managed by MotionData, which
      # is used to actually save data to the persistent store.
      #
      # This context is a `NSPrivateQueueConcurrencyType`, which means it can
      # perform saves in the background.
      def root
        unless @root
          @root = new
          @root.persistentStoreCoordinator = StoreCoordinator.default # MR does this in performBlockAndWait. Why?
        end
        @root
      end

      # This is the context that is intended for all the foreground work, such
      # as providing data to your view controllers.
      #
      # Background contexts are children of this context, which means that they
      # save their data into this context, allowing you to show data when it’s
      # not yet saved to the persistent store.
      def main
        @main ||= new(root, NSMainQueueConcurrencyType)
      end

      # Returns a new private queue context that is a child of the main context.
      #
      # These are used to perform work in the background and then push that to
      # the main queue.
      def context
        main.context
      end

      # MotionData contexts are, besides the main context, always of type
      # NSPrivateQueueConcurrencyType.
      def new(parent = nil, concurrencyType = NSPrivateQueueConcurrencyType)
        context = alloc.initWithConcurrencyType(concurrencyType)
        context.parentContext = parent if parent # do NOT set `nil`
        context
      end
    end

    # Returns a new private queue context that is a child of the this context.
    #
    # These are used to perform work in the background and then push that to
    # the main queue.
    def context
      self.class.new(self)
    end

    # Performs a block on the context's dispatch queue, while changing
    # `Context.default` to the context for the duration of the block.
    #
    # Optionally yields the context.
    def perform(&block)
      performBlock(lambda do
        Context.withDefault(self) do
          block.call(self)
        end
      end)
    end
  end
end
