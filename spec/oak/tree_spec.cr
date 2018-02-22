require "../spec_helper"

record Payload

module Oak
  describe Tree do
    describe "#glob?" do
      it "returns true when key contains a glob parameter (catch all)" do
        tree = Tree(Nil).new("a")
        tree.glob?.should be_false

        tree = Tree(Nil).new("*filepath")
        tree.glob?.should be_true
      end
    end

    describe "#key=" do
      it "accepts change of key after initialization" do
        tree = Tree(Nil).new("abc")
        tree.key.should eq("abc")

        tree.key = "xyz"
        tree.key.should eq("xyz")
      end

      it "also changes kind when modified" do
        tree = Tree(Nil).new("abc")
        tree.normal?.should be_true

        tree.key = ":query"
        tree.normal?.should be_false
        tree.named?.should be_true
      end
    end

    describe "#named?" do
      it "returns true when key contains a named parameter" do
        tree = Tree(Nil).new("a")
        tree.named?.should be_false

        tree = Tree(Nil).new(":query")
        tree.named?.should be_true
      end
    end

    describe "#normal?" do
      it "returns true when key does not contain named or glob parameters" do
        tree = Tree(Nil).new("a")
        tree.normal?.should be_true

        tree = Tree(Nil).new(":query")
        tree.normal?.should be_false

        tree = Tree(Nil).new("*filepath")
        tree.normal?.should be_false
      end
    end

    describe "#payloads" do
      it "accepts any form of payload" do
        tree = Tree.new("abc", :payload)
        tree.payloads?.should be_truthy
        tree.payloads.should contain(:payload)

        tree = Tree.new("abc", 1_000)
        tree.payloads?.should be_truthy
        tree.payloads.should contain(1_000)
      end

      # This example focuses on the internal representation of `payload`
      # as inferred from supplied types and default values.
      #
      # We cannot compare `typeof` against `property!` since it excludes `Nil`
      # from the possible types.
      it "makes optional to provide a payload" do
        tree = Tree(Int32).new("abc")
        tree.payloads?.should be_falsey
        # typeof(tree.payloads).should co ntain(Int32 | Nil)
      end
    end

    describe "#priority" do
      it "calculates it based on key length" do
        tree = Tree(Nil).new("a")
        tree.priority.should eq(1)

        tree = Tree(Nil).new("abc")
        tree.priority.should eq(3)
      end

      it "considers key length up until named parameter presence" do
        tree = Tree(Nil).new("/posts/:id")
        tree.priority.should eq(7)

        tree = Tree(Nil).new("/u/:username")
        tree.priority.should eq(3)
      end

      it "considers key length up until glob parameter presence" do
        tree = Tree(Nil).new("/search/*query")
        tree.priority.should eq(8)

        tree = Tree(Nil).new("/*anything")
        tree.priority.should eq(1)
      end

      it "changes when key changes" do
        tree = Tree(Nil).new("a")
        tree.priority.should eq(1)

        tree.key = "abc"
        tree.priority.should eq(3)

        tree.key = "/src/*filepath"
        tree.priority.should eq(5)

        tree.key = "/search/:query"
        tree.priority.should eq(8)
      end
    end

    describe "#sort!" do
      it "orders children" do
        root = Tree(Int32).new("/")
        tree1 = Tree(Int32).new("a", 1)
        tree2 = Tree(Int32).new("bc", 2)
        tree3 = Tree(Int32).new("def", 3)

        root.children.push(tree1, tree2, tree3)
        root.sort!

        root.children[0].should eq(tree3)
        root.children[1].should eq(tree2)
        root.children[2].should eq(tree1)
      end

      it "orders catch all and named parameters lower than normal trees" do
        root = Tree(Int32).new("/")
        tree1 = Tree(Int32).new("*filepath", 1)
        tree2 = Tree(Int32).new("abc", 2)
        tree3 = Tree(Int32).new(":query", 3)

        root.children.push(tree1, tree2, tree3)
        root.sort!

        root.children[0].should eq(tree2)
        root.children[1].should eq(tree3)
        root.children[2].should eq(tree1)
      end
    end

    context "a new instance" do
      it "contains a root placeholder node" do
        tree = Tree(Symbol).new
        tree.should be_a(Tree(Symbol))
        tree.payloads?.should be_falsey
        tree.placeholder?.should be_true
      end
    end

    describe "#add" do
      context "on a new instance" do
        it "replaces placeholder with new node" do
          tree = Tree(Symbol).new
          tree.add "/abc", :abc
          tree.should be_a(Tree(Symbol))
          tree.placeholder?.should be_false
          tree.payloads?.should be_truthy
          tree.payloads.should contain(:abc)
        end
      end

      context "shared root" do
        it "inserts properly adjacent nodes" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/a", :a
          tree.add "/bc", :bc

          # /    (:root)
          # +-bc (:bc)
          # \-a  (:a)
          tree.children.size.should eq(2)
          tree.children[0].key.should eq("bc")
          tree.children[0].payloads.should contain(:bc)
          tree.children[1].key.should eq("a")
          tree.children[1].payloads.should contain(:a)
        end

        it "inserts nodes with shared parent" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/abc", :abc
          tree.add "/axyz", :axyz

          # /       (:root)
          # +-a
          #   +-xyz (:axyz)
          #   \-bc  (:abc)
          tree.children.size.should eq(1)
          tree.children[0].key.should eq("a")
          tree.children[0].children.size.should eq(2)
          tree.children[0].children[0].key.should eq("xyz")
          tree.children[0].children[1].key.should eq("bc")
        end

        it "inserts multiple parent nodes" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/admin/users", :users
          tree.add "/admin/products", :products
          tree.add "/blog/tags", :tags
          tree.add "/blog/articles", :articles

          # /                 (:root)
          # +-admin/
          # |      +-products (:products)
          # |      \-users    (:users)
          # |
          # +-blog/
          #       +-articles  (:articles)
          #       \-tags      (:tags)
          tree.children.size.should eq(2)
          tree.children[0].key.should eq("admin/")
          tree.children[0].payloads?.should be_falsey
          tree.children[0].children[0].key.should eq("products")
          tree.children[0].children[1].key.should eq("users")
          tree.children[1].key.should eq("blog/")
          tree.children[1].payloads?.should be_falsey
          tree.children[1].children[0].key.should eq("articles")
          tree.children[1].children[0].payloads?.should be_truthy
          tree.children[1].children[1].key.should eq("tags")
          tree.children[1].children[1].payloads?.should be_truthy
        end

        it "inserts multiple nodes with mixed parents" do
          tree = Tree(Symbol).new
          tree.add "/authorizations", :authorizations
          tree.add "/authorizations/:id", :authorization
          tree.add "/applications", :applications
          tree.add "/events", :events

          # /
          # +-events               (:events)
          # +-a
          #   +-uthorizations      (:authorizations)
          #   |             \-/:id (:authorization)
          #   \-pplications        (:applications)
          tree.children.size.should eq(2)
          tree.children[1].key.should eq("a")
          tree.children[1].children.size.should eq(2)
          tree.children[1].children[0].payloads.should contain(:authorizations)
          tree.children[1].children[1].payloads.should contain(:applications)
        end

        it "supports insertion of mixed routes out of order" do
          tree = Tree(Symbol).new
          tree.add "/user/repos", :my_repos
          tree.add "/users/:user/repos", :user_repos
          tree.add "/users/:user", :user
          tree.add "/user", :me

          # /user                (:me)
          #     +-/repos         (:my_repos)
          #     \-s/:user        (:user)
          #             \-/repos (:user_repos)
          tree.key.should eq("/user")
          tree.payloads?.should be_truthy
          tree.payloads.should contain(:me)
          tree.children.size.should eq(2)
          tree.children[0].key.should eq("/repos")
          tree.children[1].key.should eq("s/:user")
          tree.children[1].payloads.should contain(:user)
          tree.children[1].children[0].key.should eq("/repos")
        end
      end

      context "mixed payloads" do
        it "allows node with different payloads" do
          payload1 = Payload.new
          payload2 = Payload.new

          tree = Tree(Payload | Symbol).new
          tree.add "/", :root
          tree.add "/a", payload1
          tree.add "/bc", payload2

          # /    (:root)
          # +-bc (payload2)
          # \-a  (payload1)
          tree.children.size.should eq(2)
          tree.children[0].key.should eq("bc")
          tree.children[0].payloads.should contain(payload2)
          tree.children[1].key.should eq("a")
          tree.children[1].payloads.should contain(payload1)
        end
      end

      context "dealing with unicode" do
        it "inserts properly adjacent parent nodes" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/日本語", :japanese
          tree.add "/素晴らしい", :amazing

          # /          (:root)
          # +-素晴らしい    (:amazing)
          # \-日本語      (:japanese)
          tree.children.size.should eq(2)
          tree.children[0].key.should eq("素晴らしい")
          tree.children[1].key.should eq("日本語")
        end

        it "inserts nodes with shared parent" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/日本語", :japanese
          tree.add "/日本は難しい", :japanese_is_difficult

          # /                (:root)
          # \-日本語            (:japanese)
          #     \-日本は難しい     (:japanese_is_difficult)
          tree.children.size.should eq(1)
          tree.children[0].key.should eq("日本")
          tree.children[0].children.size.should eq(2)
          tree.children[0].children[0].key.should eq("は難しい")
          tree.children[0].children[1].key.should eq("語")
        end
      end

      context "dealing with catch all and named parameters" do
        it "prioritizes nodes correctly" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/*filepath", :all
          tree.add "/products", :products
          tree.add "/products/:id", :product
          tree.add "/products/:id/edit", :edit
          tree.add "/products/featured", :featured

          # /                      (:all)
          # +-products             (:products)
          # |        \-/
          # |          +-featured  (:featured)
          # |          \-:id       (:product)
          # |              \-/edit (:edit)
          # \-*filepath            (:all)
          tree.children.size.should eq(2)
          tree.children[0].key.should eq("products")
          tree.children[0].children[0].key.should eq("/")

          nodes = tree.children[0].children[0].children
          nodes.size.should eq(2)
          nodes[0].key.should eq("featured")
          nodes[1].key.should eq(":id")
          nodes[1].children[0].key.should eq("/edit")

          tree.children[1].key.should eq("*filepath")
        end

        it "does not split named parameters across shared key" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/:category", :category
          tree.add "/:category/:subcategory", :subcategory

          # /                         (:root)
          # +-:category               (:category)
          #           \-/:subcategory (:subcategory)
          tree.children.size.should eq(1)
          tree.children[0].key.should eq(":category")

          # inner children
          tree.children[0].children.size.should eq(1)
          tree.children[0].children[0].key.should eq("/:subcategory")
        end

        it "does allow same named parameter in different order of insertion" do
          tree = Tree(Symbol).new
          tree.add "/members/:id/edit", :member_edit
          tree.add "/members/export", :members_export
          tree.add "/members/:id/videos", :member_videos

          # /members/
          #         +-export      (:members_export)
          #         \-:id/
          #              +-videos (:members_videos)
          #              \-edit   (:members_edit)
          tree.key.should eq("/members/")
          tree.children.size.should eq(2)

          # first level children nodes
          tree.children[0].key.should eq("export")
          tree.children[1].key.should eq(":id/")

          # inner children
          nodes = tree.children[1].children
          nodes[0].key.should eq("videos")
          nodes[1].key.should eq("edit")
        end

        it "does not allow different named parameters sharing same level" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/:post", :post

          expect_raises Tree::SharedKeyError do
            tree.add "/:category/:post", :category_post
          end
        end

        # TODO: uncomment when the shared key issue is overcome
        # it "allows different named parameters sharing same level" do
        #   tree = Tree(Symbol).new
        #   tree.add "/", :root
        #   tree.add "/c-:post", :post
        #   tree.add "/c-:category/p-:post", :category_post
        #   tree.add "/c-:category/p-:poll/:id", :category_poll
        #   puts tree.visualize
        #
        #   results = tree.search("/c-1")
        #   puts results.map(&.key)
        #   results.size.should eq 1
        #   results.first.payloads.size.should eq 1
        #   results.first.params.should eq({ "post" => "1" })
        #   results.first.payloads.first.should eq :post
        #
        #   results = tree.search("/a/b")
        #   results.size.should eq 1
        #   results.first.payloads.size.should eq 1
        #   results.first.params.should eq({ "category" => "a", "post" => "b" })
        #   results.first.payloads.first.should eq :category_post
        # end
      end
    end

    describe "#find" do
      context "if a matching" do
        it "should be found" do
          tree = Tree(Symbol).new
          tree.add "/about", :about

          result = tree.find("/about")
          result.found?.should be_true
          result.payload.should eq :about
        end
      end

      context "if not matching" do
        it "should not be found" do
          tree = Tree(Symbol).new
          tree.add "/about", :about

          result = tree.find("/contact")
          result.found?.should be_false
        end
      end
    end

    describe "#search" do
      context "a single node" do
        it "does not find when using different path" do
          tree = Tree(Symbol).new
          tree.add "/about", :about

          results = tree.search "/products"
          results.empty?.should be_true
        end

        it "finds when key and path matches" do
          tree = Tree(Symbol).new
          tree.add "/about", :about

          results = tree.search "/about"
          results.empty?.should be_false
          results.first.key.should eq("/about")
          results.first.payloads.empty?.should_not be_truthy
          results.first.payloads.should contain(:about)
        end

        it "finds when path contains trailing slash" do
          tree = Tree(Symbol).new
          tree.add "/about", :about

          results = tree.search "/about/"
          results.empty?.should be_false
          results.first.key.should eq("/about")
        end

        it "finds when key contains trailing slash" do
          tree = Tree(Symbol).new
          tree.add "/about/", :about

          result = tree.search "/about"
          result.empty?.should be_false
          result.first.key.should eq("/about/")
          result.first.payloads.should contain(:about)
        end
      end

      context "nodes with shared parent" do
        it "finds matching path" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/abc", :abc
          tree.add "/axyz", :axyz

          results = tree.search("/abc")
          results.empty?.should be_false
          results.first.key.should eq("/abc")
          results.first.payloads.should contain(:abc)
        end

        it "finds matching path across separator" do
          tree = Tree(Symbol).new
          tree.add "/products", :products
          tree.add "/product/new", :product_new

          results = tree.search("/products")
          results.empty?.should be_false
          results.first.key.should eq("/products")
          results.first.payloads.should contain(:products)
        end

        it "finds matching path across parents" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/admin/users", :users
          tree.add "/admin/products", :products
          tree.add "/blog/tags", :tags
          tree.add "/blog/articles", :articles

          results = tree.search("/blog/tags/")
          results.empty?.should be_false
          results.first.key.should eq("/blog/tags")
          results.first.payloads.should contain(:tags)
        end
      end

      context "unicode nodes with shared parent" do
        it "finds matching path" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/日本語", :japanese
          tree.add "/日本日本語は難しい", :japanese_is_difficult

          results = tree.search("/日本日本語は難しい/")
          results.empty?.should be_false
          results.first.key.should eq("/日本日本語は難しい")
        end
      end

      context "dealing with catch all" do
        it "finds matching path" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/*filepath", :all
          tree.add "/about", :about

          results = tree.search("/src/file.png")
          results.empty?.should be_false
          results.first.key.should eq("/*filepath")
          results.first.payloads.should contain(:all)
        end

        it "returns catch all in parameters" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/*filepath", :all
          tree.add "/about", :about

          results = tree.search("/src/file.png")
          results.empty?.should be_false
          results.first.params.has_key?("filepath").should be_true
          results.first.params["filepath"].should eq("src/file.png")
        end

        it "returns optional catch all after slash" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/search/*extra", :extra

          results = tree.search("/search")
          results.empty?.should be_false
          results.first.key.should eq("/search/*extra")
          results.first.params.has_key?("extra").should be_true
          results.first.params["extra"].empty?.should be_true
        end

        it "returns optional catch all by globbing" do
          tree = Tree(Symbol).new
          tree.add "/members*trailing", :members_catch_all

          results = tree.search("/members")
          results.empty?.should be_false
          results.first.key.should eq("/members*trailing")
          results.first.params.has_key?("trailing").should be_true
          results.first.params["trailing"].empty?.should be_true
        end

        it "does not find when catch all is not full match" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/search/public/*query", :search

          results = tree.search("/search")
          results.empty?.should be_true
        end

        it "does prefer specific path over catch all if both are present" do
          tree = Tree(Symbol).new
          tree.add "/members", :members
          tree.add "/members*trailing", :members_catch_all

          results = tree.search("/members")
          results.empty?.should be_false
          results.first.key.should eq("/members")
        end

        it "does prefer catch all over specific key with partially shared key" do
          tree = Tree(Symbol).new
          tree.add "/orders/*anything", :orders_catch_all
          tree.add "/orders/closed", :closed_orders

          results = tree.search("/orders/cancelled")
          results.empty?.should be_false
          results.first.key.should eq("/orders/*anything")
          results.first.params.has_key?("anything").should be_true
          results.first.params["anything"].should eq("cancelled")
        end
      end

      context "dealing with named parameters" do
        it "finds matching path" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/products", :products
          tree.add "/products/:id", :product
          tree.add "/products/:id/edit", :edit

          results = tree.search("/products/10")
          results.empty?.should be_false
          results.first.key.should eq("/products/:id")
          results.first.payloads.should contain(:product)
        end

        it "does not find partial matching path" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/products", :products
          tree.add "/products/:id/edit", :edit

          results = tree.search("/products/10")
          results.empty?.should be_true
        end

        it "returns named parameters in result" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/products", :products
          tree.add "/products/:id", :product
          tree.add "/products/:id/edit", :edit

          results = tree.search("/products/10/edit")
          results.empty?.should be_false
          results.first.params.has_key?("id").should be_true
          results.first.params["id"].should eq("10")
        end

        it "returns unicode values in parameters" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/language/:name", :language
          tree.add "/language/:name/about", :about

          results = tree.search("/language/日本語")
          results.empty?.should be_false
          results.first.params.has_key?("name").should be_true
          results.first.params["name"].should eq("日本語")
        end

        it "does prefer specific path over named parameters one if both are present" do
          tree = Tree(Symbol).new
          tree.add "/tag-edit/:tag", :edit_tag
          tree.add "/tag-edit2", :alternate_tag_edit

          results = tree.search("/tag-edit2")
          results.empty?.should be_false
          results.first.key.should eq("/tag-edit2")
        end

        it "does prefer named parameter over specific key with partially shared key" do
          tree = Tree(Symbol).new
          tree.add "/orders/:id", :specific_order
          tree.add "/orders/closed", :closed_orders

          results = tree.search("/orders/10")
          results.empty?.should be_false
          results.first.key.should eq("/orders/:id")
          results.first.params.has_key?("id").should be_true
          results.first.params["id"].should eq("10")
        end
      end

      context "dealing with multiple named parameters" do
        it "finds matching path" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/:section/:page", :static_page

          results = tree.search("/about/shipping")
          results.empty?.should be_false
          results.first.key.should eq("/:section/:page")
          results.first.payloads.should contain(:static_page)
        end

        it "returns named parameters in result" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/:section/:page", :static_page

          results = tree.search("/about/shipping")
          results.empty?.should be_false

          results.first.params.has_key?("section").should be_true
          results.first.params["section"].should eq("about")

          results.first.params.has_key?("page").should be_true
          results.first.params["page"].should eq("shipping")
        end
      end

      context "dealing with both catch all and named parameters" do
        it "finds matching path" do
          tree = Tree(Symbol).new
          tree.add "/", :root
          tree.add "/*filepath", :all
          tree.add "/products", :products
          tree.add "/products/:id", :product
          tree.add "/products/:id/edit", :edit
          tree.add "/products/featured", :featured

          results = tree.search("/products/1000")
          results.empty?.should be_false
          results.first.key.should eq("/products/:id")
          results.first.payloads.should contain(:product)

          results = tree.search("/admin/articles")
          results.empty?.should be_false
          results.first.key.should eq("/*filepath")
          results.first.params["filepath"].should eq("admin/articles")

          results = tree.search("/products/featured")
          results.empty?.should be_false
          results.first.key.should eq("/products/featured")
          results.first.payloads.should contain(:featured)
        end
      end

      context "dealing with named parameters and shared key" do
        it "finds matching path" do
          tree = Tree(Symbol).new
          tree.add "/one/:id", :one
          tree.add "/one-longer/:id", :two

          results = tree.search "/one-longer/10"
          results.empty?.should be_false
          results.first.key.should eq("/one-longer/:id")
          results.first.params["id"].should eq("10")
        end
      end

      context "dealing with optionals" do
        it "finds a matching path" do
          tree = Tree(Symbol).new
          tree.add "/one(/two)/:id", :one

          results = tree.search "/one/10"
          results.empty?.should be_false
          results.first.key.should eq("/one/:id")
          results.first.params["id"].should eq("10")

          results = tree.search "/one/two/20"
          results.empty?.should be_false
          results.first.key.should eq("/one/two/:id")
          results.first.params["id"].should eq("20")
        end
      end
    end
  end
end
