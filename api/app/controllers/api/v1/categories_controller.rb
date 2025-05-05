module Api
  module V1
    class CategoriesController < ::ApplicationController
      def index
        @categories = Category.all
        render json: @categories
      end

      def create
        @category = Category.new(category_params)
        
        if @category.save
          render json: @category, status: :created
        else
          render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def category_params
        params.require(:category).permit(:name)
      end
    end
  end
end 