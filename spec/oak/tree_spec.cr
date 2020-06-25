require "../spec_helper"

record Payload

module Oak
  describe Tree do
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

      context "dealing with mutliple wilcards" do
        it "finds a matching path" do
          tree = Tree(Symbol).new
          tree.add "/*foo/bar/*baz", :one

          results = tree.search "/one/bar/two"
          results.empty?.should be_false
          results.first.key.should eq("/*foo/bar/*baz")
          results.first.params["foo"].should eq("one")
          results.first.params["baz"].should eq("two")

          results = tree.search "/one/bar/baz/two"
          results.empty?.should be_false
          results.first.key.should eq("/*foo/bar/*baz")
          results.first.params["foo"].should eq("one")
          results.first.params["baz"].should eq("baz/two")

          results = tree.search "/one/two/bar/baz/three"
          results.empty?.should be_false
          results.first.key.should eq("/*foo/bar/*baz")
          results.first.params["foo"].should eq("one/two")
          results.first.params["baz"].should eq("baz/three")
        end
      end
    end
  end
end
