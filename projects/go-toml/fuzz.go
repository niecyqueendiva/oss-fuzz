package toml

func FuzzToml(data []byte) int {
	var v interface{}
	err := Unmarshal(data, &v)
	if err != nil {
		return 0
	}

	_, err = Marshal(v)
	if err != nil {
		return 0
	}

	return 1
}
