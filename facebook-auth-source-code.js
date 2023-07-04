if (!secrets.accessToken) {
  throw Error("Need to set ACCESS_TOKEN environment variable")
}
console.log(secrets.accessToken)
const profileRequest = Functions.makeHttpRequest({
  url: `https://graph.facebook.com/me?fields=id,name,picture&access_token=${secrets.accessToken}`,
  method: "GET",
})

const [profileResponse] = await Promise.all([profileRequest])
console.log(profileResponse.data)
if (!profileResponse.error) {
} else {
  throw Error("Error getting profile")
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
        src: profileResponse.data.picture.data.url,
      },
      {
        name: "text_quote",
        text: profileResponse.data.name,
        fontSize: 60,
        textBackgroundColor: "rgba(0,0,0)",
      },
      {
        name: "text_tags",
        text: "Facebook | Zixin",
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
  name: "Zixin | Facebook |" + profileResponse.data.name,
  description: "A souldbound NFT that represents the ownership of Facebook account of " + profileResponse.data.name,
  attributes: [
    {
      trait_type: "id",
      value: profileResponse.data.id,
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
