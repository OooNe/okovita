defmodule Okovita.Content.ImageTransformer do
  @moduledoc """
  Module responsible for applying specific transformations to an image using Vix/Image.
  Used as a discrete pipeline processor for the media proxy.
  """

  @doc """
  Applies image transformations (resize, blur, fit) based on the given options.
  """
  @spec process_image(Vix.Vips.Image.t(), Okovita.Content.ImageProcessor.image_opts()) ::
          {:ok, Vix.Vips.Image.t()}
  def process_image(image, opts) do
    img =
      image
      |> apply_resize(opts)
      |> apply_blur(opts)

    {:ok, img}
  end

  @spec apply_resize(Vix.Vips.Image.t(), map()) :: Vix.Vips.Image.t()
  defp apply_resize(img, %{w: w, h: h, fit: fit}) when not is_nil(w) and not is_nil(h) do
    if fit == "cover" do
      Image.thumbnail!(img, "#{w}x#{h}", crop: :center)
    else
      Image.thumbnail!(img, "#{w}x#{h}")
    end
  end

  defp apply_resize(img, %{w: w}) when not is_nil(w) do
    Image.thumbnail!(img, w)
  end

  defp apply_resize(img, %{h: h}) when not is_nil(h) do
    {width, height, _bands} = Image.shape(img)
    new_width = round(width * (h / height))
    Image.thumbnail!(img, new_width)
  end

  defp apply_resize(img, _opts), do: img

  @spec apply_blur(Vix.Vips.Image.t(), map()) :: Vix.Vips.Image.t()
  defp apply_blur(img, %{blur: blur}) when not is_nil(blur) and blur > 0 do
    Image.blur!(img, sigma: blur)
  end

  defp apply_blur(img, _opts), do: img
end
