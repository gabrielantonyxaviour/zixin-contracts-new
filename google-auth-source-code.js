if (!secrets.accessToken) {
  throw Error("Need to set ACCESS_TOKEN environment variable")
}
if (!secrets.imageApiKey) {
  throw Error("Image API Key required to fetch data from Image API. Please add it to the secrets in your request.")
}

if (!secrets.nftStorageApiKey) {
  throw Error(
    "NFT Storage API Key required to fetch data from NFT Storage API. Please add it to the secrets in your request."
  )
}
console.log(secrets.accessToken)
const emailRequest = Functions.makeHttpRequest({
  url: "https://www.googleapis.com/userinfo/v2/me",
  method: "GET",
  headers: {
    Authorization: `Bearer ${secrets.accessToken}`,
  },
})

const [profileResponse] = await Promise.all([emailRequest])
console.log(profileResponse)
if (!profileResponse.error) {
} else {
  throw Error("Error getting email")
}

const editImageRequest = Functions.makeHttpRequest({
  url: `https://rest.apitemplate.io/v2/create-image`,
  method: "POST",
  headers: { Authorization: `Token ${secrets.imageApiKey}`, "Content-Type": "application/json" },
  params: {
    template_id: "1c077b23aaf7c198",
    expiration: "0",
  },

  data: JSON.stringify({
    overrides: [
      {
        name: "background-image",
        stroke: "grey",
        src: profileResponse.data.picture,
      },
      {
        name: "text_quote",
        text: profileResponse.data.given_name + " | " + profileResponse.data.email,
        fontSize: 60,
        textBackgroundColor: "rgba(0,0,0)",
      },
      {
        name: "text_tags",
        text: "Google | Zixin",
        fontSize: 55,
        textBackgroundColor: "rgba(0, 0, 0)",
      },
    ],
  }),
})

const [editImageResponse] = await Promise.all([editImageRequest])

if (!editImageResponse.error) {
  console.log(editImageResponse.data.download_url_png)
} else {
  throw Error(editImageResponse.error)
}

const metadata = {
  name: "Zixin | Google |" + profileResponse.data.name,
  description: "A souldbound NFT that represents the ownership of Google account " + profileResponse.data.email,
  image: editImageResponse.data.picture,
  attributes: [
    {
      trait_type: "id",
      value: profileResponse.data.id,
    },
    {
      trait_type: "locale",
      value: profileResponse.data.locale,
    },
    {
      trait_type: "Given Name",
      value: profileResponse.data.given_name,
    },
    {
      trait_type: "Family Name",
      value: profileResponse.data.family_name,
    },
  ],
}

const metadataString = JSON.stringify(metadata)

const storeMetadataRequest = Functions.makeHttpRequest({
  url: `https://zixins-be1.adaptable.app/auth/store`,
  method: "POST",
  headers: { Authorization: `Bearer ${secrets.nftStorageApiKey}`, "Content-Type": "application/json" },
  data: { metadataString: metadataString },
})
const [storeMetadataResponse] = await Promise.all([storeMetadataRequest])

if (!storeMetadataResponse.error) {
  return Functions.encodeString(
    "https://" + storeMetadataResponse.data.value.cid + ".ipfs.nftstorage.link/metadata.json"
  )
} else {
  throw Error(storeMetadataResponse.data)
}
