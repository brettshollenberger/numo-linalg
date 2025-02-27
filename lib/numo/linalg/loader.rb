require "fiddle"

module Numo
  module Linalg
    module Loader

      @@libs = nil

      module_function

      def libs
        @@libs
      end

      def dlopen(recvr,base,dir=nil,ver=nil)
        if dir && !dir.empty?
          base = File.join(dir,base)
        end
        if ver && EXT=='so'
          begin
            path = "#{base}.#{EXT}.#{ver}"
            recvr.send(:dlopen,path)
            return path
          rescue
          end
        end
        path = "#{base}.#{EXT}"
        recvr.send(:dlopen,path)
        path
      end
      private :dlopen

      def load_mkl(*dirs,exc:true)
        if dirs.empty?
          dirs = [MKL_LIBPATH,""].compact
        end
        dirs.each do |d|
          if d.empty?
            d = e = nil
          else
            e = d.sub(/\/mkl\//, "/")
          end
          begin
            f_iomp5 = dlopen(Fiddle,"libiomp5",e)
            f_mkl_core = dlopen(Fiddle,"libmkl_core",d)
            f_intel_thread = dlopen(Fiddle,"libmkl_intel_thread",d)
            f_intel_lp64 = dlopen(Blas,"libmkl_intel_lp64",d)
            f_intel_lp64 = dlopen(Lapack,"libmkl_intel_lp64",d)
            @@libs = [ f_iomp5, f_mkl_core, f_intel_thread, f_intel_lp64 ]
            if $DEBUG
              $stderr.puts "Numo::Linalg: use #{f_intel_lp64}"
            end
            return true
          rescue
          end
        end
        if exc
          raise RuntimeError, "cannot find MKL library"
        end
        false
      end

      def load_openblas(*dirs,exc:true)
        if dirs.empty?
          dirs = [OPENBLAS_LIBPATH,""].compact
        end
        dirs.each do |d|
          %w[ libopenblaso
              libopenblasp
              libopenblas  ].each do |f|
            begin
              f_openblas = dlopen(Blas,f,d,0)
              f_openblas = dlopen(Fiddle,f,d,0)
              f_lapacke = nil
              begin
                f_lapacke = dlopen(Lapack,"liblapacke",d,3)
              rescue
                f_openblas = dlopen(Lapack,f,d,0)
              end
              @@libs = [ f_openblas, f_lapacke ].compact
              if $DEBUG
                $stderr.puts "Numo::Linalg: use #{f}"
              end
              return true
            rescue
            end
          end
        end
        if exc
          raise RuntimeError, "cannot find OpenBLAS library"
        end
        false
      end

      def load_atlas(*dirs,exc:true)
        if dirs.empty?
          dirs = [ATLAS_LIBPATH,""].compact
        end
        dirs.each do |d|
          %w[ libtatlas
              libatlas
              libsatlas ].each do |f|
            begin
              f_atlas = dlopen(Fiddle,f,d,3)
              f_atlas = dlopen(Blas,f,d,3)
              f_lapacke = dlopen(Lapack,"liblapacke",LAPACK_LIBPATH,3)
              @@libs = [ f_atlas, f_lapacke ]
              if $DEBUG
                $stderr.puts "Numo::Linalg: use #{f}"
              end
              return true
            rescue
            end
          end
        end
        if exc
          raise RuntimeError, "cannot find ATLAS library"
        end
        false
      end

      def load_lapack(*dirs,exc:true)
        if dirs.empty?
          b = BLAS_LIBPATH || LAPACK_LIBPATH
          l = LAPACK_LIBPATH || BLAS_LIBPATH
          dirs = (b ? [[b,l]] : []) + ["",""]
        end
        dirs.each do |arg|
          b,l = *arg
          l = b if l.nil?
          begin
            f_blas = dlopen(Fiddle,"libblas",b,3)
            f_lapack = dlopen(Fiddle,"liblapack",l,3)
            f_cblas = dlopen(Blas,"libcblas",b,3)
            f_lapacke = dlopen(Lapack,"liblapacke",l,3)
            @@libs = [ f_blas, f_lapack, f_cblas, f_lapacke ]
            if $DEBUG
              $stderr.puts "Numo::Linalg: use #{f_blas} and #{f_lapack}"
            end
            return true
          rescue
          end
        end
        if exc
          raise RuntimeError, "cannot find BLAS/LAPABK library"
        end
        false
      end

      def self.load_accelerate(exc: true)
        puts "Attempting to load Accelerate framework..." if $DEBUG

        # Check if we have a custom LAPACKE library built for Accelerate
        lapacke_path = File.expand_path("../../../ext/lapacke_install/lib/liblapacke.dylib", __dir__)
        puts "Checking for custom LAPACKE at: #{lapacke_path}" if $DEBUG
        custom_lapacke_exists = File.exist?(lapacke_path)
        puts "Custom LAPACKE exists: #{custom_lapacke_exists}" if $DEBUG

        # Load Accelerate's BLAS
        blas_path = "/System/Library/Frameworks/Accelerate.framework/Versions/A/Frameworks/vecLib.framework/libBLAS.dylib"
        puts "Attempting to load BLAS from: #{blas_path}" if $DEBUG
        blas = dlopen(Fiddle, "libBLAS", blas_path.sub(/\/libBLAS\.dylib$/, ""))
        blas = dlopen(Blas, "libBLAS", blas_path.sub(/\/libBLAS\.dylib$/, ""))
        
        # Load Accelerate's LAPACK
        lapack_path = "/System/Library/Frameworks/Accelerate.framework/Versions/A/Frameworks/vecLib.framework/libLAPACK.dylib"
        puts "Attempting to load LAPACK from: #{lapack_path}" if $DEBUG
        lapack = dlopen(Fiddle, "libLAPACK", lapack_path.sub(/\/libLAPACK\.dylib$/, ""))
        
        # Load custom LAPACKE if available
        if custom_lapacke_exists
          puts "Loading custom LAPACKE from: #{lapacke_path}" if $DEBUG
          begin
            lapacke = Fiddle.dlopen(lapacke_path)
            lapacke = dlopen(Lapack, "liblapacke", lapacke_path.sub(/\/liblapacke\.dylib$/, ""))
            puts "Successfully loaded custom LAPACKE library" if $DEBUG
            @@libs = [blas_path, lapack_path, lapacke_path]
            return [blas, lapack, lapacke]
          rescue Fiddle::DLError => e
            puts "Error loading custom LAPACKE: #{e.message}" if $DEBUG
            # Fall back to Accelerate without LAPACKE
          end
        end
        
        # If we get here, either custom LAPACKE doesn't exist or failed to load
        puts "Successfully loaded BLAS and LAPACK from vecLib framework" if $DEBUG
        puts "Note: Some advanced LAPACK functions may not be available as Accelerate lacks LAPACKE interface" if $DEBUG
        puts "Run ./build_accelerate_lapacke.sh to build a custom LAPACKE library for full functionality" if $DEBUG
        
        @@libs = [blas_path, lapack_path]
        [blas, lapack]
      end

      def using_accelerate_without_lapacke?
        @@using_accelerate_without_lapacke ||= false
      end

      def load_library
        case BACKEND
        when /mkl/i; return if load_mkl(exc: false)
        when /^openblas/i; return if load_openblas(exc: false)
        when /^atlas/i; return if load_atlas(exc: false)
        when /lapack|blas/i; return if load_lapack(exc: false)
        when /accelerate/i; return if load_accelerate(exc: false)
        else
          # On Apple ARM, try Accelerate first
          if apple_arm?
            return if load_accelerate(exc: false)
          end
          
          # Try other backends
          return if load_mkl(exc: false)
          return if load_openblas(exc: false)
          return if load_atlas(exc: false)
          return if load_lapack(exc: false)
          
          # If we're on Apple ARM and we've reached this point, try Accelerate again with exceptions enabled
          if apple_arm?
            return if load_accelerate(exc: true)
          end
        end
        raise RuntimeError, "cannot find backend library for Numo::Linalg"
      end

      def apple_arm?
        RUBY_PLATFORM =~ /arm64-darwin/ ? true : false
      end
    end
  end
end